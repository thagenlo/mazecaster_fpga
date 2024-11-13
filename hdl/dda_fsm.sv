module dda
#(
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 240,
  parameter N = 24
)
(
  input wire pixel_clk_in, //TODO check if correct clock
  input wire rst_in,
  input wire [10:0] hcount_ray_in, // current ray x-coordinate ranging from 0 -> screenWidth (11-bit uint)
  //input wire [3:0] step_in, // stepX [3:2], stepY[1:0]
  input wire [1:0] step_in, // stepX[1], stepY[0]
  input wire [31:0] rayDir_in, //rayDirX [31:16], rayDirY [15:0]
  input wire [31:0] sideDist_in, // distance ray travels to first x-side/y-side -> sideDistX [31:16], sideDistY [15:0]
  input wire [31:0] deltaDist_in, // distance ray travels to go from 1 x-side to the next x-side, or from 1 y-side to the next y-side -> deltaDistX [31:16], deltaDistY [15:0]
  input wire [13:0] map_in, //current box of the map we're in - mapX[13:7], mapY[6:0] (8-bit uint)

  input wire ready_in,//TODO -> needed? when ready_in high + busy_out low -> ready state, set busy_out high, remove from stack

  //handling map data requests
  input wire [2:0] map_data; //value of worldMap[mapX][mapY] 0->7
  input wire map_data_ready; //single cycle - indicates new map data is ready
  output logic [$clog2(N*N)-1:0] map_addra; //map_addr = mapX + (mapY × N) (e.g. 24*24, [9:0])
  output logic map_request; // high when new map_addra request

  output logic [7:0] hcount_ray_out, // screen x_coord (not pipelines)
  output logic [15:0] lineHeight_out, // = SCREEN_HEIGHT/perpWallDist
  output logic wallType_out, // 0 = X wall hit, 1 = Y wall hit
  output logic [7:0] mapData_out;  // value 0 -> 2^8 at map[mapX][mapY] from BROM //TODO store in intermediate register?
  output logic [15:0] wallX_out; //where on wall the ray hits

    //TODO figure out handshakes
  output logic busy_out, // high when DDA FSM in use
  output logic valid_out, // single cycle - indicates DDA_hit a wall & has found line height (informs articulator)
  
  );

    //CHANGE TO TAKE FULL FIFO ROW AS INPUT???

    logic [7:0] X;
    assign hcount_ray_out = hcount_ray_in;

    logic stepX, stepY;
    assign stepX = step_in[1];
    assign stepY = step_in[0];
    // assign stepX = step_in[3:2]; // 2'b10 = -1 (left), 2'b01 = 1 (right), 2'b00 = 0 (none)
    // assign stepY = step_in[1:0]; // 2'b10 = -1 (back), 2'b01 = 1 (forward), 2'b00 = 0 (none)

    logic [15:0] deltaDistX, deltaDistY, sideDistX, sideDistY;
    assign deltaDistX = deltaDist_in[31:16];
    assign deltaDistY = deltaDist_in[15:0];

    logic [7:0] mapX, mapY;

    logic wallType;

    //store value in index
    logic [7:0] mapData_store;

    //store perpWallDist
    logic [15:0] perpWallDist;


  
    enum {
        READY, X_STEP, Y_STEP, CHECK_WALL, VALID_OUT
    } DDA_FSM_STATE;


    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            DDA_FSM_STATE <= READY;
            //TODO initialize values in reset
            map_data <= 0;
            map_request <= 0;
            busy_out <= 0;
            
        end else begin
            case (DDA_FSM_STATE)

                IDLE: begin
                    busy_out <= 1'b0;
                    valid_out <= 1'b0;
                    if (ready_in) begin
                        DDA_FSM_STATE <= READY;
                    end
                end

                READY: begin
                    busy_out <= 1'b1;

                    sideDistX <= sideDist_in[31:16];
                    sideDistY <= sideDist_in[15:0];
                    mapX <= map_in[13:7];
                    mapY <= map_in[6:0];

                    DDA_FSM_STATE <= (sideDist_in[31:16] < sideDist_in[15:0])?  X_STEP : // if sideDistX < sideDistY
                                                                                Y_STEP;  // if sideDistX >= sideDistY
                end

                X_STEP: begin
                    sideDistX <= sideDistX + deltaDistX;
                    mapX <= (stepX == 1'b0)? mapX - 1'b1: // 0 => -1 (left) 
                                             mapX + 1'b1; // 1 => 1 (right)
                    wallType <= 1'b0; // x-wall

                    //map_addr = mapX + (mapY × N)
                    map_addra <= (stepX == 1'b0)? (mapX - 1'b1) + (N * (mapY)): // 0 => -1 (left) 
                                                  (mapX + 1'b1) + (N * (mapY)); // 1 => 1 (right)
                    
        
                    //send request to BRAM for map data
                    map_request <= 1'b1;


                    DDA_FSM_STATE <= CHECK_WALL;
                end

                Y_STEP: begin
                    sideDistY <= sideDistY + deltaDistY;
                    mapY <= (stepY == 1'b0)? mapY - 1'b1: // 0 => -1 (back) 
                                             mapY + 1'b1; // 1 => 1 (forward)
                    wallType <= 1'b1; // y-wall

                    //map_addr = mapX + (mapY × N)
                    map_addra <= (stepY == 1'b0)? mapX + (N * (mapY-1)): 
                                                  mapX + (N * (mapY+1));

                    //send request to BRAM for map data
                    map_request <= 1'b1;


                    DDA_FSM_STATE <= CHECK_WALL;
                end

                CHECK_WALL: begin
                    //map_data <= worldMap[mapX][mapY];
                    //worldMap[mapX][mapY] //TODO - get this data from BRAM - how many cycles?

                    map_request <= 0;  // Clear the request signal
                    if (map_data_ready) begin
                        mapData_store <= map_data;
                        if (map_data != 0) 
                            DDA_FSM_STATE <= WALL_CALC; // Wall detected
                            perpWallDist <= (wallType == 1'b0)? sideDistX - deltaDistX: // 0 => x-wall
                                                                sideDistY - deltaDistY; // 1 => y-wall
                        else if (sideDistX < sideDistY)
                            DDA_FSM_STATE <= X_STEP;  // Continue stepping in X
                        else
                            DDA_FSM_STATE <= Y_STEP;  // Continue stepping in Y
                    end
                end

                WALL_CALC: begin

                    lineHeight_out <= SCREEN_HEIGHT / perpWallDist; //TODO THIS DIVISION POOPOO

                    wallType_out <= wallType; // 0 => x-wall, 1 => y-wall

                    //where exactly the wall was hit ( fractional part [7:0] -> wallX -= floor((wallX)) ) //TODO pipeline?
                    wallX_out <= (wallType == 1'b0)? (posX + (perpWallDist * rayDirX))[7:0]: // 0 => x-wall
                                                     (posY + (perpWallDist * rayDirY))[7:0]; // 1 => y-wall

                    mapData_out <= mapData_store; // value from 0->7 at map[mapX][mapY] from BRAM

                    DDA_FSM_STATE <= VALID_OUT;

                end

                VALID_OUT: begin
                    valid_out <= 1'b1;
                    busy_out <= 1'b0;
                    DDA_FSM_STATE <= IDLE;
                    
                end
                default: DDA_FSM_STATE <= IDLE;  
            endcase
        end
    end


endmodule