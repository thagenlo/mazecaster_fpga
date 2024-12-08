module movement_control #(
    parameter ROTATION_ANGLE = 16'b0010_1101_0000_0000 // default = 45 degrees
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
    output logic signed [15:0] planeY
    );//

    // localparam logic [15:0] COS_OF_45 = 16'sh00B5; //cos(45) = 0.7071 in FP
    // localparam logic [15:0] SIN_OF_45 = 16'sh00B5; //sin(45) = 0.7071 in FP (but it into Q1.15 )
    // localparam logic [15:0] NEG_COS_OF_45 = 16'sh00B5;
    // localparam logic [15:0] NEG_SIN_OF_45 = 16'shFF4B;

    localparam logic [15:0] COS_OF_45 = 16'sh2d41; //cos(45) = 0.7071 in FP
    localparam logic [15:0] SIN_OF_45 = 16'sh2d41; //sin(45) = 0.7071 in FP (but it into Q1.15 )
    localparam logic [15:0] NEG_COS_OF_45 = 16'sh2d41;
    localparam logic [15:0] NEG_SIN_OF_45 = 16'shd2bf;

    localparam MOVE_SPEED = 32'sh00000100;
    // localparam NEG_MOVE_SPEED = 16'sb1111_1111_0000_0000;
    
    logic signed [32:0] tempDirX, tempDirY;
    logic signed [31:0] tempPosX, tempPosY;
    logic signed [32:0] tempPlaneX, tempPlaneY;
    logic signed [32:0] tempDirX2, tempDirY2;
    logic signed [31:0] tempPosX2, tempPosY2;
    logic signed [32:0] tempPlaneX2, tempPlaneY2;
    logic signed [15:0] oldPosX;
    logic signed [15:0] oldPosY;
    logic signed [15:0] oldDirX;
    logic signed [15:0] oldDirY;
    logic signed [15:0] oldPlaneX;
    logic signed [15:0] oldPlaneY;

    // always_comb begin
    // end
    logic second_stage;
    logic third_stage;
    // logic multiplying_logic;
    // logic addition_logic;


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
            tempPosX <= $signed({8'b0, 16'h0b80, 8'b0});
            tempPosY <= $signed({8'b0, 16'h0b80, 8'b0});
            tempDirX <= $signed({2'b0, 16'h0000, 14'b0});
            tempDirY <= $signed({2'b0, 16'hFF00, 14'b0});
            tempPlaneX <= $signed({2'b0, 16'h00A9, 14'b0});
            tempPlaneY <= $signed({2'b0, 16'h0000, 14'b0});
            // LOOKING INTO LOWER RIGHT CORNER
            oldPosX <= 16'h0480; //4.5
            oldPosY <= 16'h0c80; //12.5
            oldDirX <= 16'h00b5; //.707
            oldDirY <= 16'h00b5; //.707
            oldPlaneX <= 16'shFF89; //-0.464
            oldPlaneY <= 16'sh0077; //0.464
            second_stage <= 0;
            third_stage<=0;
        end else begin
            if (is_pulse) begin
                second_stage <= 1;
                if (fwd_pulse) begin
                    // second_stage <= 1;
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirX * MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosY, 8'b0}) + oldDirY * MOVE_SPEED;
                    tempDirX <= $signed({2'b0, oldDirX, 14'b0});
                    tempDirY <= $signed({2'b0, oldDirY, 14'b0});
                    tempPlaneX <= $signed({2'b0, oldPlaneX, 14'b0});
                    tempPlaneY <= $signed({2'b0, oldPlaneY, 14'b0});
                end
                else if (bwd_pulse) begin
                    // second_stage <= 1;
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) - oldDirX * MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosY, 8'b0}) - oldDirY * MOVE_SPEED;
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
                    // tempDirX <= $$signed(oldDirX) * $signed(NEG_COS_OF_45[15:0]) - $signed(oldDirY[15:0]) * $signed(NEG_SIN_OF_45[15:0]);
                    // tempDirY <= $signed(oldDirX) * $signed(NEG_SIN_OF_45[15:0]) + $signed(oldDirY[15:0]) * $signed(NEG_COS_OF_45[15:0]);
                    // tempPlaneX <= $signed(oldPlaneX) * $signed(NEG_COS_OF_45[15:0]) - $signed(oldPlaneY[15:0]) * $signed(NEG_SIN_OF_45[15:0]);
                    // tempPlaneY <= $signed(oldPlaneX) * $signed(NEG_SIN_OF_45[15:0]) + $signed(oldPlaneY[15:0]) * $signed(NEG_COS_OF_45[15:0]);
                end
            end
            else if (second_stage) begin
                second_stage <= 0;
                tempPosX2 <= tempPosX;
                tempPosY2 <= tempPosY;
                tempDirX2 <= tempDirX;
                tempDirY2 <= tempDirY;
                tempPlaneX2 <= tempPlaneX;
                tempPlaneY2 <= tempPlaneY;
                third_stage <= 1;
            end else if (third_stage) begin
                third_stage<=0;
                oldPosX <= $signed(tempPosX[23:8]);
                oldPosY <= $signed(tempPosY[23:8]);
                oldDirX <= $signed(tempDirX[29:14]);
                oldDirY <= $signed(tempDirY[29:14]);
                oldPlaneX <= $signed(tempPlaneX[29:14]);
                oldPlaneY <= $signed(tempPlaneY[29:14]);
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
