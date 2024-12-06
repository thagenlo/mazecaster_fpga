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

    localparam COS_OF_45 = 16'sb0000000010110101; //cos(10) = 0.70703125 in FP
    localparam SIN_OF_45 = 16'sb0000000010110101;
    localparam NEG_COS_OF_45 = 16'sb1111111101001011;
    localparam NEG_SIN_OF_45 = 16'sb1111111101001011;

    localparam MOVE_SPEED = 16'sb0000_0001_0000_0000;
    localparam NEG_MOVE_SPEED = 16'sb1111_1111_0000_0000;
    
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
        if (rst_in) begin //initial pos/orientation middle looking straight upward
            oldPosX <= 16'sh0b80; //12.5
            oldPosY <= 16'sh0b80;//12.5
            oldDirX <= 16'sh0000; //0
            oldDirY <= 16'shFF00; //-1
            oldPlaneX <= 16'sh00A9;
            oldPlaneY <= 16'sh0000;
            second_stage <= 0;
        end else begin
            if (is_pulse) begin
                second_stage <= 1;
                if (fwd_pulse) begin
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirX * MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirY * MOVE_SPEED;
                    tempDirX <= $signed({8'b0, oldDirX, 8'b0});
                    tempDirY <= $signed({8'b0, oldDirY, 8'b0});
                    tempPlaneX <= $signed({8'b0, oldPlaneX, 8'b0});
                    tempPlaneY <= $signed({8'b0, oldPlaneY, 8'b0});
                end
                else if (bwd_pulse) begin
                    tempPosX <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirX * NEG_MOVE_SPEED;
                    tempPosY <=  $signed({8'b0, oldPosX, 8'b0}) + oldDirY * NEG_MOVE_SPEED;
                    tempDirX <= $signed({8'b0, oldDirX, 8'b0});
                    tempDirY <= $signed({8'b0, oldDirY, 8'b0});
                    tempPlaneX <= $signed({8'b0, oldPlaneX, 8'b0});
                    tempPlaneY <= $signed({8'b0, oldPlaneY, 8'b0});
                end
                // Rotation logic
                else if (leftRot_pulse) begin
                    tempPosX <= $signed({8'b0, oldPosX, 8'b0});
                    tempPosY <= $signed({8'b0, oldPosY, 8'b0});
                    tempDirX <= oldDirX * COS_OF_45 + oldDirY * NEG_SIN_OF_45;
                    tempDirY <= oldDirX * SIN_OF_45 + oldDirY * COS_OF_45;
                    tempPlaneX <= oldPlaneX * COS_OF_45 + oldPlaneY * NEG_SIN_OF_45;
                    tempPlaneY <= oldPlaneX * SIN_OF_45 + oldPlaneY * COS_OF_45;
                end
                else if (rightRot_pulse) begin
                    tempPosX <= $signed({8'b0, oldPosX, 8'b0});
                    tempPosY <= $signed({8'b0, oldPosY, 8'b0});
                    tempDirX <= oldDirX * COS_OF_45 + oldDirY * SIN_OF_45;
                    tempDirY <= oldDirX * NEG_SIN_OF_45 + oldDirY * COS_OF_45;
                    tempPlaneX <= oldPlaneX * COS_OF_45 + oldPlaneY * SIN_OF_45;
                    tempPlaneY <= oldPlaneX * NEG_SIN_OF_45 + oldPlaneY * COS_OF_45;
                end
            end
            else if (second_stage) begin
                second_stage <= 0;
                oldPosX <= $signed(tempPosX[23:8]);
                oldPosY <= $signed(tempPosY[23:8]);
                oldDirX <= $signed(tempDirX[23:8]);
                oldDirY <= $signed(tempDirY[23:8]);
                oldPlaneX <= $signed(tempPlaneX[23:8]);
                oldPlaneY <= $signed(tempPlaneY[23:8]);
                //input VALID
            end
        end
    end
    
    assign posX = oldPosX;
    assign posY = oldPosY;
    assign dirX = oldDirX;
    assign dirY = oldDirY;
    assign planeX = oldPlaneX;
    assign planeY = oldPlaneY;

    // localparam signed COS_OF_45 = 16'sb0000000010110101; //cos(10) = 0.70703125 in FP
    // localparam signed SIN_OF_45 = 16'sb0000000010110101;
    // localparam signed NEG_COS_OF_45 = 16'sb1111111101001011;
    // localparam signed NEG_SIN_OF_45 = 16'sb1111111101001011;

    // localparam signed MOVE_SPEED = 16'sb0000_0001_0000_0000;
    // localparam signed NEG_MOVE_SPEED = 16'sb1111_1111_0000_0000;

    // oldPosX <= $signed(tempPosX[23:8]);
    // oldPosY <= $signed(tempPosY[23:8]);
    // oldDirX <= $signed(tempDirX[23:8]);
    // oldDirY <= $signed(tempDirY[23:8]);
    // oldPlaneX <= $signed(tempPlaneX[23:8]);
    // oldPlaneY <= $signed(tempPlaneY[23:8]);
    // tempDirX <= $signed(oldDirX * COS_OF_45 + oldDirY * SIN_OF_45);
    //                 tempDirY <= $signed(oldDirX * NEG_SIN_OF_45 + oldDirY * COS_OF_45);
    //                 tempPlaneX <= $signed(oldPlaneX * COS_OF_45 + oldPlaneY * SIN_OF_45);
    //                 tempPlaneY <= $signed(oldPlaneX * NEG_SIN_OF_45 + oldPlaneY * COS_OF_45);

endmodule
