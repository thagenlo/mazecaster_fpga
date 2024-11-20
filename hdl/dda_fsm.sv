module dda
#(
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 240,
  parameter N = 24
)
(
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [] dda_data_in; //TODO (hcount_ray[10:0], stepX/stepY[3:0], rayDirX/rayDirY[31:0], deltaDistX/deltaDistY[31:0], posX/posY[31:0] , sideDistX/sideDistY[31:0], mapX/mapY[13:0])
  input wire valid_in; //single cycle high for new dda_data_in

  //handling map data requests
  input wire [3:0] map_data_in; // value 0 -> 16 output from BROM at map_addra_out
  input wire map_data_valid_in; //single cycle high for new map data from BRAM is ready
  output logic [$clog2(N*N)-1:0] map_addra_out; //map_addra = mapX + (mapY × N) (e.g. 24*24, [9:0])
  output logic map_request_out; // high when new map_addra is requested, low after map_data_valid_in

  output logic [8:0] hcount_ray_out, // current ray/sreen x-coordinate - (11-bit uint) (0 -> screenWidth)
  output logic [7:0] lineHeight_out, //log_2(240) - 8-bit uint
  //output logic [15:0] lineHeight_out, // = SCREEN_HEIGHT/perpWallDist - (8.8 fixed point) TODO
  output logic wallType_out, // 0 -> X wall hit, 1 -> Y wall hit (1-bit uint)
  output logic [3:0] mapData_out;  // value 0 -> 16 at map[mapX][mapY] from BROM
  output logic [7:0] wallX_out; //where on wall the ray hits - 8-bit uint (fractional part of 8.8 fixed point value)

    // handshakes
  output logic dda_busy_out, // high when DDA FSM in use
  output logic dda_valid_out, // single cycle - indicates DDA_hit a wall & has found line height (informs articulator)
  
  );

    // ---- INPUT CONSTANTS ----
        //TODO split up dda_data_in variables
    logic [8:0] hcount_ray; // current ray/screen x-coordinate
    assign hcount_ray = dda_data_in[]; // 11-bit uint (0 -> screenWidth)

    logic [1:0] stepX, stepY; //which dir to take step
    //assign stepX = dda_data_in[]; // 0 => -1 (left), 1 => 1 (right) - ( 1-bit uint )
    //assign stepY = dda_data_in[]; // 0 => -1 (back), 1 => 1 (forward) - ( 1-bit uint )
    assign stepX = $signed(dda_data_in[]); // 2'b10 = -1, 2'b01 = 1 - (2-bit two's complement)
    assign stepY = $signed(dda_data_in[]); // 2'b10 = -1, 2'b01 = 1 - (2-bit two's complement)

    logic [15:0] rayDirX, rayDirY; // x & y componentions of ray vector (used to calculate wallX_out)
    assign rayDirX = $signed(dda_data_in[]); // 8.8 signed fixed point 
    assign rayDirY = $signed(dda_data_in[]); // 8.8 signed fixed point 

    logic [15:0] deltaDistX, deltaDistY; // distance ray travels to go from 1 x/y-side to the next x/y-side
    assign deltaDistX = dda_data_in[]; // 8.8 fixed point 
    assign deltaDistY = dda_data_in[]; // 8.8 fixed point 

    logic [15:0] posX, posY; // position of camera/player
    assign posX = dda_data_in[]; // 8.8 fixed point 
    assign posY = dda_data_in[]; // 8.8 fixed point 

    // ---- UPDATE W/ STEP ----

    // init w/ input
    logic [15:0] sideDistX, sideDistY; //distance ray travels to first x-side/y-side ( 8.8 fixed point )
    logic [6:0] mapX, mapY; // current x, y box of player position (7-bit uint) - log_2(90) = 7
    // no iniit
    logic wallType; // 0 -> X wall hit, 1 -> Y wall hit (1-bit uint)

    // ---- SINGLE STORE FOR OUTPUT ----

    logic [7:0] mapData_store; // value 0 -> 16 at map[mapX][mapY] from BROM
    logic [15:0] perpWallDist;

    // ---- PIPELINES ----

    // X_STEP
    // logic [$clog2(N*N)-1:0] map_addra_out_pipe_x [2:0]; //3 stage pipeline
    // logic [$clog2(N*N)-1:0] map_addra_out_pipe_y [2:0]; //3 stage pipeline

    //CHECK_WALL
    logic [15:0] rayDir_X_or_Y //signed 8.8 signed fixed point 
    logic [15:0] pos_X_or_Y // 8.8 fixed point 

    //WALL_CALC
    localparam logic [15:0] SCREEN_HEIGHT_FIXED_POINT = SCREEN_HEIGHT << 8;

    logic [3:0] wall_calc_counter; // Counter for division latency 0 -> 10 (4-bit uint)
    logic signed [31:0] wallX_out_intermediate;
  
    ////############ STEP FSM ###############

    enum {
        IDLE, READY, X_STEP, Y_STEP, CHECK_WALL, WALL_CALC, VALID_OUT
    } DDA_FSM_STATE;


    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            dda_busy_out <= 1'b0;
            dda_valid_out <= 1'b0;

            map_addra_out <= 0;
            map_request_out <= 1'b0;
            busy_out <= 0;

            hcount_ray_out <= 0;
            lineHeight_out <= 0;
            wallType_out <= 0;
            mapData_out <= 0;
            wallX_out <= 0;

            wall_calc_counter <= 4'b0;

            DDA_FSM_STATE <= IDLE;
            
        end else begin
            case (DDA_FSM_STATE)

                IDLE: begin
                    dda_busy_out <= 1'b0;
                    dda_valid_out <= 1'b0;

                    if (valid_in) begin
                        DDA_FSM_STATE <= READY;
                    end
                end

                READY: begin
                    dda_busy_out <= 1'b1;

                    wall_calc_counter <= 4'b0;

                    sideDistX <= dda_data_in[]; //TODO
                    sideDistY <= dda_data_in[]; //TODO
                    mapX <= dda_data_in[]; //TODO
                    mapY <= dda_data_in[]; //TODO

                    DDA_FSM_STATE <= (dda_data_in[] < dda_data_in[])?  X_STEP : // if sideDistX < sideDistY
                                                                       Y_STEP;  // if sideDistX >= sideDistY

                end

                X_STEP: begin
                    sideDistX <= sideDistX + deltaDistX;

                    mapX <= (stepX == 1'b0)? mapX - 1'b1: // 1'b0 => -1
                                             mapX + 1'b1; // 1'b1 => 1

                    wallType <= 1'b0; // x-wall

                    //map_addr = mapX + (mapY × N) - single cycle (check?)
                    map_addra_out <= (stepX == 1'b0)? (mapX - 1'b1) + (N * (mapY)): 
                                                      (mapX + 1'b1) + (N * (mapY));

                    // map_request_out_pipe_x[0] <= 1'b1;
                    // for (int i=1; i<3; i = i+1)begin //3 stage pipeline
                    //     map_request_out_pipe_x[i] <= map_request_out_pipe_x[i-1];
                    //     if (map_request_out_pipe_x[2] == 1'b1) begin
                    //         DDA_FSM_STATE <= CHECK_WALL;
                    //     end
                    // end
                    
                    //send request to BRAM for map data
                    map_request_out <= 1'b1;

                    DDA_FSM_STATE <= CHECK_WALL; 
                end

                Y_STEP: begin
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

                    if (map_data_valid_in) begin
                        map_request_out <= 1'b0;  // clear the request signal
                        mapData_store <= map_data_in; //store map data locally
                        if (map_data_in != 0) begin
                            DDA_FSM_STATE <= WALL_CALC; // wall detected
                            perpWallDist <= (wallType == 1'b0)? sideDistX - deltaDistX: // 0 => x-wall
                                                                sideDistY - deltaDistY; // 1 => y-wall
                            // set as X or Y for wall_calc
                            pos_X_or_Y <= (wallType == 1'b0)? posX : posY;
                            rayDir_X_or_Y <= (wallType == 1'b0)? $signed(rayDirX) : $signed(rayDirY);

                        end else if (sideDistX < sideDistY) begin
                            DDA_FSM_STATE <= X_STEP;  // Continue stepping in X
                        end else begin
                            DDA_FSM_STATE <= Y_STEP;  // Continue stepping in Y
                        end
                    end
                end

                WALL_CALC: begin

                    lineHeight_out <= SCREEN_HEIGHT / perpWallDist; //TODO THIS DIVISION POOPOO

                    wallType_out <= wallType; // 0 => x-wall, 1 => y-wall
                    mapData_out <= mapData_store; // value from 0->7 at map[mapX][mapY] from BRAM

                    wall_calc_counter <= wall_calc_counter + 1'b1;

                    // ~10 cycles
                    // TODO check if line height will take up entire screen? - have some sort of range - 
                    // perpWallDist 0 -> N * sqrt(2)
                    lineHeight_out <= SCREEN_HEIGHT_FIXED_POINT / perpWallDist; //TODO THIS DIVISION POOPOO

                    // ~6 cycles?
                    //where exactly the wall was hit ( fractional part [7:0] -> wallX -= floor((wallX)) ) //TODO pipeline?
                    // wallX_out <= (wallType == 1'b0)? (posX + (perpWallDist * rayDirX))[7:0]: // 0 => x-wall
                    //                                  (posY + (perpWallDist * rayDirY))[7:0]; // 1 => y-wall
                    wallX_out_intermediate <= $signed(perpWallDist) * $signed(rayDir_X_or_Y);

                    if (wall_calc_counter == 15) begin //account for 15 cycles of latency
                        wallX_out <= (pos_X_or_Y + (wallX_out_intermediate >>> 8))[7:0];

                        DDA_FSM_STATE <= VALID_OUT;
                    end

                end

                VALID_OUT: begin
                    dda_valid_out <= 1'b1;
                    dda_busy_out <= 1'b0;
                    DDA_FSM_STATE <= IDLE;
                end

                default: DDA_FSM_STATE <= IDLE;  
            endcase
        end
    end


endmodule