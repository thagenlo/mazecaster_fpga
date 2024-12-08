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

    localparam COS_OF_45 = 32'sh000000B5; //cos(45) = 0.7071 in FP
    localparam SIN_OF_45 = 32'sh000000B5; //sin(45) = 0.7071 in FP
    localparam NEG_COS_OF_45 = 32'shFFFFFF4B;
    localparam NEG_SIN_OF_45 = 32'shFFFFFF4B;

    localparam MOVE_SPEED = 32'sh00000100;
    // localparam NEG_MOVE_SPEED = 16'sb1111_1111_0000_0000;
    
    logic signed [31:0] tempDirX, tempDirY;
    logic signed [31:0] tempPosX, tempPosY;
    logic signed [31:0] tempPlaneX, tempPlaneY;
    logic signed [15:0] oldPosX;
    logic signed [15:0] oldPosY;
    logic signed [15:0] oldDirX;
    logic signed [15:0] oldDirY;
    logic signed [15:0] oldPlaneX;
    logic signed [15:0] oldPlaneY;

    // always_comb begin
    // end
    logic second_stage;

    // typedef enum {FWD, BWD, ROTLEFT, ROTRIGHT} divider_state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin 
            //initial pos/orientation middle looking straight forward (upward in 2D grid)
            oldPosX <= 16'sh0b80; // 11.5
            oldPosY <= 16'sh0b80; // 11.5
            oldDirX <= 16'sh0000; // 0
            oldDirY <= 16'shFF00; // -1
            oldPlaneX <= 16'sh00A9; // 0.66
            oldPlaneY <= 16'sh0000; // O
            tempPosX <= $signed({8'b0, 16'sh0b80, 8'b0});
            tempPosY <= $signed({8'b0, oldPosY, 8'b0});
            tempDirX <= $signed({8'b0, oldDirX, 8'b0});
            tempDirY <= $signed({8'b0, oldDirY, 8'b0});
            tempPlaneX <= $signed({8'b0, oldPlaneX, 8'b0});
            tempPlaneY <= $signed({8'b0, oldPlaneY, 8'b0});
            // LOOKING INTO LOWER RIGHT CORNER
            // oldPosX <= 16'h0480; //4.5
            // oldPosY <= 16'h0c80; //12.5
            // oldDirX <= 16'h00b5; //.707
            // oldDirY <= 16'h00b5; //.707
            // oldPlaneX <= 16'shFF89; //-0.464
            // oldPlaneY <= 16'sh0077; //0.464
            second_stage <= 0;
        end else begin
            if (is_pulse) begin
                second_stage <= 1;
                if (fwd_pulse) begin
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirX * MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosY, 8'b0}) + oldDirY * MOVE_SPEED;
                    tempDirX <= $signed({8'b0, oldDirX, 8'b0});
                    tempDirY <= $signed({8'b0, oldDirY, 8'b0});
                    tempPlaneX <= $signed({8'b0, oldPlaneX, 8'b0});
                    tempPlaneY <= $signed({8'b0, oldPlaneY, 8'b0});
                end
                else if (bwd_pulse) begin
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) - oldDirX * MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosY, 8'b0}) - oldDirY * MOVE_SPEED;
                    tempDirX <= $signed({8'b0, oldDirX, 8'b0});
                    tempDirY <= $signed({8'b0, oldDirY, 8'b0});
                    tempPlaneX <= $signed({8'b0, oldPlaneX, 8'b0});
                    tempPlaneY <= $signed({8'b0, oldPlaneY, 8'b0});
                end
                else if (leftRot_pulse) begin
                    tempPosX <= $signed({8'b0, oldPosX, 8'b0});
                    tempPosY <= $signed({8'b0, oldPosY, 8'b0});
                    tempDirX <= $signed(oldDirX) * $signed(COS_OF_45) - $signed(oldDirY) * $signed(SIN_OF_45);
                    tempDirY <= $signed(oldDirX) * $signed(SIN_OF_45) + $signed(oldDirY) * $signed(COS_OF_45);
                    tempPlaneX <= $signed(oldPlaneX) * $signed(COS_OF_45) - $signed(oldPlaneY) * $signed(SIN_OF_45);
                    tempPlaneY <= $signed(oldPlaneX) * $signed(SIN_OF_45) + $signed(oldPlaneY) * $signed(COS_OF_45);
                end
                else if (rightRot_pulse) begin
                    tempPosX <= $signed({8'b0, oldPosX, 8'b0});
                    tempPosY <= $signed({8'b0, oldPosY, 8'b0});
                    tempDirX <= $signed(oldDirX) * $signed(NEG_COS_OF_45[15:0]) - $signed(oldDirY[15:0]) * $signed(NEG_SIN_OF_45[15:0]);
                    tempDirY <= $signed(oldDirX) * $signed(NEG_SIN_OF_45[15:0]) + $signed(oldDirY[15:0]) * $signed(NEG_COS_OF_45[15:0]);
                    tempPlaneX <= $signed(oldPlaneX) * $signed(NEG_COS_OF_45[15:0]) - $signed(oldPlaneY[15:0]) * $signed(NEG_SIN_OF_45[15:0]);
                    tempPlaneY <= $signed(oldPlaneX) * $signed(NEG_SIN_OF_45[15:0]) + $signed(oldPlaneY[15:0]) * $signed(NEG_COS_OF_45[15:0]);
                end
            end
            else if (second_stage) begin
                second_stage <= 0;
                oldPosX <= tempPosX[23:8];
                oldPosY <= tempPosY[23:8];
                oldDirX <= tempDirX[23:8];
                oldDirY <= tempDirY[23:8];
                oldPlaneX <= tempPlaneX[23:8];
                oldPlaneY <= tempPlaneY[23:8];
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
