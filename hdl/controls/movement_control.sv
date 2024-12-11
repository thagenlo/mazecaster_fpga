module movement_control #(
    parameter ROTATION_ANGLE = 16'b0010_1101_0000_0000, // default = 45 degrees
    parameter N = 24
    )(input wire clk_in,
    input wire rst_in,
    input wire fwd_pulse, 
    input wire bwd_pulse, 
    input wire leftRot_pulse, 
    input wire rightRot_pulse,
    input wire is_pulse,
    output logic signed [15:0] posX, 
    output logic signed [15:0] posY,
    output logic signed [15:0] dirX, 
    output logic signed [15:0] dirY,
    output logic signed [15:0] planeX, 
    output logic signed [15:0] planeY,

    output logic ray_grid_req,
    output logic [$clog2(N*N)-1:0] ray_map_addra,
    input wire ray_grid_valid,
    input wire [4:0] ray_grid_data
    //input wire [1:0] map_select
    );//

    localparam logic [15:0] COS_OF_45 = 16'sh3f07; //cos(10) = 3ff6 (0.9993896484375)
    localparam logic [15:0] SIN_OF_45 = 16'sh0b1d; //sin(10) = 0.7071 in FP (but it into Q2.15 )
    localparam logic [15:0] NEG_COS_OF_45 = 16'sh3f07;
    localparam logic [15:0] NEG_SIN_OF_45 = 16'shf4e3; //cos(2) = 3ff6 (0.9993896484375)

    // localparam MOVE_SPEED = 32'sh00000100;
    localparam MOVE_SPEED = 32'sh0000_0080; //speed = .1
    localparam INC_MOVE_SPEED = 32'sh00001eb8; //.12
    // localparam NEG_MOVE_SPEED = 16'sb1111_1111_0000_0000;
    
    logic signed [32:0] tempDirX, tempDirY;
    logic signed [31:0] tempPosX, tempPosY;
    logic signed [32:0] tempPlaneX, tempPlaneY;
    // logic signed [32:0] tempDirX2, tempDirY2;
    // logic signed [31:0] tempPosX2, tempPosY2;
    // logic signed [32:0] tempPlaneX2, tempPlaneY2;
    logic signed [15:0] oldPosX;
    logic signed [15:0] oldPosY;
    logic signed [15:0] oldDirX;
    logic signed [15:0] oldDirY;
    logic signed [15:0] oldPlaneX;
    logic signed [15:0] oldPlaneY;

    //logic signed [31:0] tempPosX_check, tempPosY_check;

    // always_comb begin
    // end
    logic second_stage;
    logic third_stage;
    // logic multiplying_logic;
    // logic addition_logic;

    // logic [7:0] mapX, mapY;
    // assign mapX = tempPosX_check[23:16];
    // assign mapY = tempPosY_check[23:16];


    // typedef enum {FWD, BWD, ROTLEFT, ROTRIGHT} divider_state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin 
            //initial pos/orientation middle looking straight forward (upward in 2D grid)
            // oldPosX <= 16'sh0b80; // 11.5
            // oldPosY <= 16'sh0b80; // 11.5
            // oldDirX <= 16'sh0000; // 0
            // oldDirY <= 16'shFF00; // -1
            // oldPlaneX <= 16'sh00A9; // 0.66
            // oldPlaneY <= 16'sh0000; // O
            ray_map_addra <= 0;
            ray_grid_req <= 0;

            tempPosX <= $signed({8'b0, 16'h0b80, 8'b0});
            tempPosY <= $signed({8'b0, 16'h0b80, 8'b0});
            tempDirX <= $signed({2'b0, 16'h0000, 14'b0});
            tempDirY <= $signed({2'b0, 16'hFF00, 14'b0});
            tempPlaneX <= $signed({2'b0, 16'h00A9, 14'b0});
            tempPlaneY <= $signed({2'b0, 16'h0000, 14'b0});
            // LOOKING INTO LOWER RIGHT CORNER
            // oldPosX <= 16'h0480; //4.5
            // oldPosY <= 16'h0c80; //12.5
            oldPosX <= 16'h0100; //1
            oldPosY <= 16'h0100; //1
            oldDirX <= 16'h00b5; //.707
            oldDirY <= 16'h00b5; //.707
            oldPlaneX <= 16'shFF89; //-0.464
            oldPlaneY <= 16'sh0077; //0.464
            second_stage <= 0;
            third_stage<=0;
        end else begin
            if (third_stage) begin
                if (ray_grid_valid) begin
                    third_stage<=0;
                    if (ray_grid_data == 0) begin
                        oldPosX <= $signed(tempPosX[23:8]);
                        oldPosY <= $signed(tempPosY[23:8]);
                    end
                    oldDirX <= $signed(tempDirX[29:14]);
                    oldDirY <= $signed(tempDirY[29:14]);
                    oldPlaneX <= $signed(tempPlaneX[29:14]);
                    oldPlaneY <= $signed(tempPlaneY[29:14]);
                    
                    ray_grid_req <= 0;
                end
            end
            else if (second_stage) begin
                second_stage <= 0;
                // tempPosX2 <= tempPosX;
                // tempPosY2 <= tempPosY;
                // tempDirX2 <= tempDirX;
                // tempDirY2 <= tempDirY;
                // tempPlaneX2 <= tempPlaneX;
                // tempPlaneY2 <= tempPlaneY;
                third_stage <= 1;
                //map access
                ray_map_addra <= mapX + (N * mapY);
                ray_grid_req <= 1;

                //if oldDirX > 0 check mapX - oldPosX > .5
                //if oldDirX < 0 check mapX - oldPosX < -.5
                // deltaX <= $signed(mapX) - oldPosX;
                // //if oldDirY > 0 check mapY - oldPosY > .5
                // //if oldDirY < 0 check mapY - oldPosY < -.5
                // deltaY <= $signed(mapY) - oldPosY;

            end else if (is_pulse) begin
                second_stage <= 1;
                if (fwd_pulse) begin
                    // second_stage <= 1;
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirX * MOVE_SPEED;
                    //tempPosX_check <= $signed({8'b0, oldPosX, 8'b0}) + oldDirX * INC_MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosY, 8'b0}) + oldDirY * MOVE_SPEED;
                    //tempPosY_check <= $signed({8'b0, oldPosX, 8'b0}) + oldDirX * INC_MOVE_SPEED;
                    tempDirX <= $signed({2'b0, oldDirX, 14'b0});
                    tempDirY <= $signed({2'b0, oldDirY, 14'b0});
                    tempPlaneX <= $signed({2'b0, oldPlaneX, 14'b0});
                    tempPlaneY <= $signed({2'b0, oldPlaneY, 14'b0});
                end
                else if (bwd_pulse) begin
                    // second_stage <= 1;
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) - oldDirX * MOVE_SPEED;
                    //tempPosX_check <=  $signed({8'b0, oldPosX, 8'b0}) - oldDirX * INC_MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosY, 8'b0}) - oldDirY * MOVE_SPEED;
                    //tempPosY_check <=  $signed({8'b0, oldPosY, 8'b0}) - oldDirY * INC_MOVE_SPEED;
                    tempDirX <= $signed({2'b0, oldDirX, 14'b0});
                    tempDirY <= $signed({2'b0, oldDirY, 14'b0});
                    tempPlaneX <= $signed({2'b0, oldPlaneX, 14'b0});
                    tempPlaneY <= $signed({2'b0, oldPlaneY, 14'b0});
                end
                else if (leftRot_pulse) begin
                    tempPosX <= $signed({8'b0, oldPosX, 8'b0});
                    tempPosY <= $signed({8'b0, oldPosY, 8'b0});
                    tempDirX <= $signed(oldDirX) * $signed(NEG_COS_OF_45) - $signed(oldDirY) * $signed(NEG_SIN_OF_45);
                    tempDirY <= $signed(oldDirX) * $signed(NEG_SIN_OF_45) + $signed(oldDirY) * $signed(NEG_COS_OF_45);
                    tempPlaneX <= $signed(oldPlaneX) * $signed(NEG_COS_OF_45) - $signed(oldPlaneY) * $signed(NEG_SIN_OF_45);
                    tempPlaneY <= $signed(oldPlaneX) * $signed(NEG_SIN_OF_45) + $signed(oldPlaneY) * $signed(NEG_COS_OF_45);

                end
                else if (rightRot_pulse) begin
                    tempPosX <= $signed({8'b0, oldPosX, 8'b0});
                    tempPosY <= $signed({8'b0, oldPosY, 8'b0});
                    tempDirX <= $signed(oldDirX) * $signed(COS_OF_45) - $signed(oldDirY) * $signed(SIN_OF_45);
                    tempDirY <= $signed(oldDirX) * $signed(SIN_OF_45) + $signed(oldDirY) * $signed(COS_OF_45);
                    tempPlaneX <= $signed(oldPlaneX) * $signed(COS_OF_45) - $signed(oldPlaneY) * $signed(SIN_OF_45);
                    tempPlaneY <= $signed(oldPlaneX) * $signed(SIN_OF_45) + $signed(oldPlaneY) * $signed(COS_OF_45);
                end
            end
        end
    end
    
    assign posX = oldPosX;
    assign posY = oldPosY;
    assign dirX = oldDirX;
    assign dirY = oldDirY;
    assign planeX = oldPlaneX;
    assign planeY = oldPlaneY;
endmodule
