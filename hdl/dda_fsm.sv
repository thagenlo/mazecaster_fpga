// `ifdef SIMULATION
//     always @(posedge pixel_clk_in) begin
//         $display("Time: %0t | State: %0d | hcount_ray_out: %0d | mapX: %0d | mapY: %0d", 
//                 $time, DDA_FSM_STATE, hcount_ray_out, mapX, mapY);
        
//         // $display("Time: %0t | State: %0d | hcount_ray_out: %0d | mapX: %0d | mapY: %0d | sideDistX: %0d | sideDistY: %0d", 
//         //         $time, DDA_FSM_STATE, hcount_ray_out, mapX, mapY, sideDistX, sideDistY);

//     end
// `endif

module dda_fsm
#(
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 180,
  parameter N = 24
)
(
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [138:0] dda_data_in, //(hcount_ray[8:0], stepX/stepY[1:0], rayDirX/rayDirY[31:0], deltaDistX/deltaDistY[31:0], posX/posY[31:0], sideDistX/sideDistY[31:0])
  input wire valid_in, //single cycle high for new dda_data_in

  input wire dda_fsm_out_tready, // FIFO has valid data available for the receiver

  //handling map data requests
  input wire [3:0] map_data_in, // value 0 -> 16 output from BROM at map_addra_out
  input wire map_data_valid_in, //single cycle high for new map data from BRAM is ready
  output logic [$clog2(N*N)-1:0] map_addra_out, //map_addra = mapX + (mapY × N) (e.g. 24*24, [9:0])
  output logic map_request_out, // high when new map_addra is requested, low after map_data_valid_in

  output logic [8:0] hcount_ray_out, // current ray/screen x-coordinate - (11-bit uint) (0 -> screenWidth)
  output logic [7:0] lineHeight_out, //log_2(180) - 8-bit uint
  output logic wallType_out, // 0 -> X wall hit, 1 -> Y wall hit (1-bit uint)
  output logic [3:0] mapData_out,  // value 0 -> 16 at map[mapX][mapY] from BROM
  output logic [15:0] wallX_out, //where on wall the ray hits - 16 bit fixed point (fractional part of 8.8 fixed point value)

    // handshakes
  output logic dda_busy_out, // high when DDA FSM in use
  output logic dda_valid_out // single cycle - indicates DDA_hit a wall & has found line height (informs articulator)
  );

    // ---- INPUT CONSTANTS ----

    // logic [8:0] hcount_ray; // current ray/screen x-coordinate
    // assign hcount_ray = dda_data_in[]; // 9-bit uint (0 -> screenWidth)
    assign hcount_ray_out = dda_data_in[138:130];

    logic stepX, stepY; //which dir to take step
    assign stepX = dda_data_in[129]; // 1'b0 = -1, 1'b1 = 1 - (1-bit uint)
    assign stepY = dda_data_in[128]; // 1'b0 = -1, 1'b1 = 1 - (1-bit uint)

    logic [15:0] rayDirX, rayDirY; // x & y componentions of ray vector (used to calculate wallX_out)
    assign rayDirX = dda_data_in[127:112]; //TODO TEMP VAL (UNTIL TEXTURES NEEDED)
    assign rayDirY = dda_data_in[111:96]; //TODO TEMP VAL (UNTIL TEXTURES NEEDED)
    // always_comb begin
    //     if (dda_data_in[127:112]) begin // negative
    //         rayDirX = ~dda_data_in[127:112] + 16'd1; // Two's complement
    //     end else begin
    //         rayDirX = dda_data_in[127:112]; // if positive, retain original value
    //     end
    //     if (dda_data_in[111:96]) begin // negative
    //         rayDirY = ~dda_data_in[111:96] + 16'd1; // Two's complement
    //     end else begin
    //         rayDirY = dda_data_in[111:96]; // if positive, retain original value
    //     end
    // end

    logic [15:0] deltaDistX, deltaDistY; // distance ray travels to go from 1 x/y-side to the next x/y-side
    assign deltaDistX = dda_data_in[95:80]; // 8.8 fixed point 
    assign deltaDistY = dda_data_in[79:64]; // 8.8 fixed point 

    logic [15:0] posX, posY; // position of camera/player
    assign posX = dda_data_in[63:48]; // 8.8 fixed point 
    assign posY = dda_data_in[47:32]; // 8.8 fixed point 


    // ---- UPDATE W/ STEP ----

    // init w/ input
    logic [15:0] sideDistX, sideDistY; //distance ray travels to first x-side/y-side ( 8.8 fixed point )
    logic [7:0] mapX, mapY; // current x, y box of player position (8-bit uint)
    // no iniit
    logic wallType; // 0 -> X wall hit, 1 -> Y wall hit (1-bit uint)

    // ---- SINGLE STORE FOR OUTPUT ----

    logic [7:0] mapData_store; // value 0 -> 16 at map[mapX][mapY] from BROM
    logic [15:0] perpWallDist;

    // ---- PIPELINES ----

    //CHECK_WALL
    logic [15:0] rayDir_X_or_Y; //signed 8.8 signed fixed point 
    logic [15:0] pos_X_or_Y; // 8.8 fixed point 

    //WALL_CALC
    logic [31:0] wallX_out_intermediate;

    logic div_start_in; // start division
    logic div_done_out;
    //logic div_busy_out, div_valid_out;
    logic [15:0] div_numerator_in, div_denominator_in; // 8.8 fixed-point
    logic [15:0] div_quotient_out; // 8.8 fixed-point

    divu #(
        .WIDTH(16),
        .FBITS(8)
    ) divu_inst (
        .clk(pixel_clk_in),
        .rst(rst_in),
        .start(div_start_in),
        .busy(),
        .done(div_done_out),
        .valid(),
        .dbz(),
        .ovf(),
        .a(div_numerator_in), //screen_height 8.8 unsigned fixed point
        .b(div_denominator_in),
        .val(div_quotient_out)
    );

  
    ////############ STEP FSM ###############

    enum {
        IDLE, READY, X_STEP, Y_STEP, CHECK_WALL, WALL_CALC, VALID_OUT
    } DDA_FSM_STATE;


    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            // $display("Time: %0t | Resetting DDA FSM", $time);
            dda_busy_out <= 1'b0;
            dda_valid_out <= 1'b0;

            map_addra_out <= 0;
            map_request_out <= 1'b0;

            lineHeight_out <= 0;
            wallType_out <= 0;
            mapData_out <= 0;
            wallX_out <= 0;

            DDA_FSM_STATE <= IDLE;
            
        end else begin
            // $display("Time: %0t | State: %0d | hcount_ray_out: %0d | mapX: %0d | mapY: %0d", 
            //      $time, DDA_FSM_STATE, hcount_ray_out, mapX, mapY);

            case (DDA_FSM_STATE)

                IDLE: begin
                    //$display("valid_out: %0d", dda_valid_out);
                    //$display("Time: %0t | IDLE State", $time);
                    dda_busy_out <= 1'b0;
                    dda_valid_out <= 1'b0;

                    if (valid_in) begin
                        DDA_FSM_STATE <= READY;
                    end
                end

                READY: begin
                    // $display("Time: %0t | READY State | posX: %0d | posY: %0d | sideDistX: %0d | sideDistY: %0d",
                    //      $time, posX, posY, sideDistX, sideDistY);

                    dda_busy_out <= 1'b1;

                    sideDistX <= dda_data_in[31:16];
                    sideDistY <= dda_data_in[15:0];
                    mapX <= posX[15:8];
                    mapY <= posY[15:8];

                    DDA_FSM_STATE <= (dda_data_in[31:16] < dda_data_in[15:0])?  X_STEP : // if sideDistX < sideDistY
                                                                       Y_STEP;  // if sideDistX >= sideDistY

                end

                X_STEP: begin
                    //$display("Time: %0t | X_STEP State | hcount_ray_out: %0d | mapX: %0d | mapY: %0d | sideDistX: %0d | sideDistY: %0d", $time, hcount_ray_out, mapX, mapY, sideDistX, sideDistY);

                    sideDistX <= sideDistX + deltaDistX;

                    mapX <= (stepX == 1'b0)? mapX - 1'b1: // 1'b0 => -1
                                             mapX + 1'b1; // 1'b1 => 1

                    wallType <= 1'b0; // x-wall

                    //map_addr = mapX + (mapY × N) - single cycle (check?)
                    map_addra_out <= (stepX == 1'b0)? (mapX - 1'b1) + (N * (mapY)): 
                                                      (mapX + 1'b1) + (N * (mapY));
                    
                    //send request to BRAM for map data
                    map_request_out <= 1'b1;

                    DDA_FSM_STATE <= CHECK_WALL; 
                end

                Y_STEP: begin
                    //$display("Time: %0t | Y_STEP State | hcount_ray_out: %0d | mapX: %0d | mapY: %0d | sideDistX: %0d | sideDistY: %0d", $time, hcount_ray_out, mapX, mapY, sideDistX, sideDistY);

                    sideDistY <= sideDistY + deltaDistY;

                    mapY <= (stepY == 1'b0)? mapY - 1'b1: // 1'b0 => -1 
                                             mapY + 1'b1; // 1'b1 => 1

                    wallType <= 1'b1; // y-wall

                    //map_addr = mapX + (mapY × N) - single cycle?
                    map_addra_out <= (stepY == 1'b0)? mapX + (N * (mapY - 1'b1)): 
                                                       mapX + (N * (mapY + 1'b1)); 

                    //send request to BRAM for map data
                    map_request_out <= 1'b1;

                    DDA_FSM_STATE <= CHECK_WALL;
                end

                CHECK_WALL: begin
                    //$display("Time: %0t | CHECK_WALL State | hcount_ray_out: %0d | mapX: %0d | mapY: %0d | sideDistX: %0d | sideDistY: %0d | map_data_in: %0d", $time, hcount_ray_out, mapX, mapY, sideDistX, sideDistY, map_data_in);

                    if (map_data_valid_in) begin
                        map_request_out <= 1'b0;  // clear the request signal
                        mapData_store <= map_data_in; //store map data locally
                        if (map_data_in != 0) begin
                            //$display("Time: %0t | Wall detected! Transitioning to WALL_CALC", $time);
                            
                            //TODO WHEN TEXTURES NEEDED
                            // perpWallDist <= (wallType == 1'b0)? sideDistX - deltaDistX: // 0 => x-wall
                            //                                     sideDistY - deltaDistY; // 1 => y-wall

                            // set as X or Y for wall_calc
                            pos_X_or_Y <= (wallType == 1'b0)? posX : posY;
                            rayDir_X_or_Y <= (wallType == 1'b0)? rayDirX : rayDirY; 

                            //start division (screenHeight / perpWallDist)
                            div_start_in <= 1'b1;
                            div_denominator_in <= (wallType == 1'b0)? (sideDistX - deltaDistX): 
                                                                       (sideDistY - deltaDistY);
                            div_numerator_in <= 16'b1011_0100_0000_0000; //screen_height = 180

                            DDA_FSM_STATE <= WALL_CALC; // wall detected

                        end else if (sideDistX < sideDistY) begin
                            DDA_FSM_STATE <= X_STEP;  // Continue stepping in X
                        end else begin
                            DDA_FSM_STATE <= Y_STEP;  // Continue stepping in Y
                        end
                    end
                end

                WALL_CALC: begin
                    //$display("Time: %0t | WALL_CALC State | perpWallDist: %0d", $time, perpWallDist);
                    //$display("Time: %0t | WALL_CALC State | hcount_ray_out: %0d | mapX: %0d | mapY: %0d | sideDistX: %0d | sideDistY: %0d", $time, hcount_ray_out, mapX, mapY, sideDistX, sideDistY);
                    
                    wallType_out <= wallType; // 0 => x-wall, 1 => y-wall
                    mapData_out <= mapData_store; // value from 0->7 at map[mapX][mapY] from BRAM


                    //$display("Time: %0t | DIVISION: numerator=%0d, denominator=%0d", $time, div_numerator_in, div_denominator_in);

                    // ~16 cycles?
                    // possible efficiency considerations?
                    // perpWallDist 0 -> N * sqrt(2), lineHeight_out 0 -> SCREEN_HEIGHT
                            // full screen -> if perpWallDist[15:8] == 0, lineHeight_out <= SCREEN_HEIGHT
                            // 1 pixel -> if perpWallDist[15:8] > SCREEN_HEIGHT, lineHeight_out <= 1; (will never be 0 pixels b/c 240*sqrt(2) = 339)
                    //lineHeight_out <= screenHeight / perpWallDist;
                    div_start_in <= 1'b0;

                    // ~6 cycles?
                    //where exactly the wall was hit ( fractional part [7:0] -> wallX -= floor((wallX)) ) 
                    // wallX_out <= (wallType == 1'b0)? (posX + (perpWallDist * rayDirX))[7:0]: // 0 => x-wall
                    //                                  (posY + (perpWallDist * rayDirY))[7:0]; // 1 => y-wall
                    
                    //wallX_out_intermediate <= perpWallDist * rayDir_X_or_Y; //TODO check later for textures ray direction is absolute val (check)

                    if (div_done_out) begin
                        //$display("Time: %0t | hcount_ray_out: %0d | DIVISION DONE: quotient=%0d", $time,hcount_ray_out, div_quotient_out);

                        wallX_out <= 16'b1111_1111_1111_1111; //(pos_X_or_Y + {8'b0, wallX_out_intermediate[7:0]})[8:0]; //TODO check later for textures

                        //TODO div_quotient_out is zero when player is super close to wall
                        lineHeight_out <= (div_quotient_out == 0)? SCREEN_HEIGHT : div_quotient_out[15:8];

                        DDA_FSM_STATE <= VALID_OUT;
                    end

                end

                VALID_OUT: begin
                    // $display("Time: %0t | VALID_OUT State | hcount_ray_out: %0d | lineHeight_out: %0d | wallType_out: %0d", 
                    //      $time, hcount_ray_out, lineHeight_out, wallType_out);

                    if (dda_fsm_out_tready) begin// data is not sent to the FIFO unless dda_fsm_out_tready is high
                        //$display("valid_out: %0d", dda_valid_out);
                        dda_valid_out <= 1'b1;
                        dda_busy_out <= 1'b0;
                        DDA_FSM_STATE <= IDLE;
                    end
                end

                default: begin
                    //$display("Time: %0t | Invalid State", $time);
                    DDA_FSM_STATE <= IDLE;  
                end
            endcase
        end
    end


endmodule
