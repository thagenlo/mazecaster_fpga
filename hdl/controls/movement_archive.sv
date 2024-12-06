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

    localparam signed COS_OF_45 = 16'b0000000010110101; //cos(10) = 0.70703125 in FP
    localparam signed SIN_OF_45 = 16'b0000000010110101;
    localparam signed NEG_COS_OF_45 = 16'b1111111101001011;
    localparam signed NEG_SIN_OF_45 = 16'b1111111101001011;

    localparam signed MOVE_SPEED = 16'b0000_0001_0000_0000;
    localparam signed NEG_MOVE_SPEED = 16'b1111_1111_0000_0000;
    
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
    logic multiplying_logic;
    logic adding_logic;

    typedef enum {FWD, BWD, ROTLEFT, ROTRIGHT} divider_state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin //initial pos/orientation middle looking straight upward
            posX <= 16'b0000110010000000; //12.5
            posY <= 16'b0000110010000000;//12.5
            dirX <= 16'b0; //0
            dirY <= 16'b1111111100000000; //-1
            planeX <= 16'b0000000010101001;
            planeY <= 16'b0;
            second_stage <= 0;
            multiplying_logic <= 1;
        end else begin
            oldPosX <= posX;
            oldPosY <= posY;
            oldDirX <= dirX;
            oldDirY <= dirY;
            oldPlaneX <= planeX;
            oldPlaneY <= planeY;
            if (is_pulse) begin
                second_stage <= 1;
                multiplying_logic <= 1;
                if (fwd_pulse) begin
                    if (multiplying_logic) begin
                        tempPosX <= $signed(oldDirX * MOVE_SPEED);
                        tempPosY <= $signed(oldDirY * MOVE_SPEED);
                    end else if (adding_logic) begin
                        tempPosX <= oldPosX + tempPosX[23:8];
                        tempPosY <= oldPosY + tempPosY[23:8];
                    end
                    tempDirX <= {8'b0, oldDirX, 8'b0};
                    tempDirY <= {8'b0, oldDirY, 8'b0};
                    tempPlaneX <= {8'b0, oldPlaneX, 8'b0};
                    tempPlaneY <= {8'b0, oldPlaneY, 8'b0};
                end
                else if (bwd_pulse) begin
                    tempPosX <= oldPosX + (oldDirX * NEG_MOVE_SPEED);
                    tempPosY <= oldPosY + (oldDirY * NEG_MOVE_SPEED);
                    tempDirX <= {8'b0, oldDirX, 8'b0};
                    tempDirY <= {8'b0, oldDirY, 8'b0};
                    tempPlaneX <= {8'b0, oldPlaneX, 8'b0};
                    tempPlaneY <= {8'b0, oldPlaneY, 8'b0};
                end
                // Rotation logic
                else if (leftRot_pulse) begin
                    tempPosX <= {8'b0, oldPosX, 8'b0};
                    tempPosY <= {8'b0, oldPosY, 8'b0};
                    tempDirX <= (oldDirX * COS_OF_45 + oldDirY * NEG_SIN_OF_45);
                    tempDirY <= (oldDirX * SIN_OF_45 + oldDirY * COS_OF_45);
                    tempPlaneX <= (oldPlaneX * COS_OF_45 + oldPlaneY * NEG_SIN_OF_45);
                    tempPlaneY <= (oldPlaneX * SIN_OF_45 + oldPlaneY * COS_OF_45);
                end
                else if (rightRot_pulse) begin
                    tempPosX <= {8'b0, oldPosX, 8'b0};
                    tempPosY <= {8'b0, oldPosY, 8'b0};
                    tempDirX <=(oldDirX * COS_OF_45 + oldDirY * SIN_OF_45);
                    tempDirY <=(oldDirX * NEG_SIN_OF_45 + oldDirY * COS_OF_45);
                    tempPlaneX <=(oldPlaneX * COS_OF_45 + oldPlaneY * SIN_OF_45);
                    tempPlaneY <=(oldPlaneX * NEG_SIN_OF_45 + oldPlaneY * COS_OF_45);
                end
            end
            else if (second_stage) begin
                second_stage <=0;
                posX <= tempPosX[23:8];
                posY <= tempPosY[23:8];
                dirX <= tempDirX[23:8];
                dirY <= tempDirY[23:8];
                planeX <= tempPlaneX[23:8];
                planeY <= tempPlaneY[23:8];
                //INPUT VALID
            end
        
        end
    end
    

endmodule

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

    localparam signed COS_OF_45 = 16'b0000000010110101; //cos(10) = 0.70703125 in FP
    localparam signed SIN_OF_45 = 16'b0000000010110101;
    localparam signed NEG_COS_OF_45 = 16'b1111111101001011;
    localparam signed NEG_SIN_OF_45 = 16'b1111111101001011;

    localparam signed MOVE_SPEED = 16'b0000_0001_0000_0000;
    localparam signed NEG_MOVE_SPEED = 16'b1111_1111_0000_0000;
    
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
    logic calculation_1;
    logic calculation_2;

    typedef enum {FWD, BWD, ROTLEFT, ROTRIGHT} divider_state;

    always_ff @(posedge clk_in) begin
        if (rst_in) begin //initial pos/orientation middle looking straight upward
            posX <= 16'b0000110010000000; //12.5
            posY <= 16'b0000110010000000;//12.5
            dirX <= 16'b0; //0
            dirY <= 16'b1111111100000000; //-1
            planeX <= 16'b0000000010101001;
            planeY <= 16'b0;
            second_stage <= 0;
            calculation_1 <= 0;
            calculation_2 <= 0;
        end else begin
            oldPosX <= posX;
            oldPosY <= posY;
            oldDirX <= dirX;
            oldDirY <= dirY;
            oldPlaneX <= planeX;
            oldPlaneY <= planeY;
            if (is_pulse) begin
                second_stage <= 1;
                calculation_1 <= 1;
                if (fwd_pulse) begin
                    if (calculation_1) begin
                        calculation_1 <= 0;
                        calculation_2 <= 1;
                        tempPosX <= $signed(oldDirX * MOVE_SPEED);
                        tempPosY <= $signed(oldDirY * MOVE_SPEED);
                        tempDirX <= {8'b0, oldDirX, 8'b0};
                        tempDirY <= {8'b0, oldDirY, 8'b0};
                        tempPlaneX <= {8'b0, oldPlaneX, 8'b0};
                        tempPlaneY <= {8'b0, oldPlaneY, 8'b0};
                    end else if (calculation_2) begin
                        calculation_2 <= 0;
                        tempPosX <= {8'b0, oldPosX, 8'b0} + tempPosX[23:8];
                        tempPosY <= {8'b0, oldPosY, 8'b0} + tempPosY[23:8];
                    end
                end
                else if (bwd_pulse) begin
                    if (calculation_1) begin
                        calculation_1 <= 0;
                        calculation_2 <= 1;
                        tempPosX <= $signed(oldDirX * NEG_MOVE_SPEED);
                        tempPosY <= $signed(oldDirY * NEG_MOVE_SPEED);
                        tempDirX <= {8'b0, oldDirX, 8'b0};
                        tempDirY <= {8'b0, oldDirY, 8'b0};
                        tempPlaneX <= {8'b0, oldPlaneX, 8'b0};
                        tempPlaneY <= {8'b0, oldPlaneY, 8'b0};
                    end else if (calculation_2) begin
                        calculation_2 <= 0;                        
                        tempPosX <= {8'b0, oldPosX, 8'b0} + tempPosX[23:8];
                        tempPosY <= {8'b0, oldPosX, 8'b0} + tempPosY[23:8];
                    end
                end
                // Rotation logic
                else if (leftRot_pulse) begin
                    if (calculation_1) begin
                        calculation_1 <= 0;
                        calculation_2 <= 1;
                        tempPosX <= oldPosX + tempPosX[23:8];
                        tempPosY <= oldPosY + tempPosY[23:8];
                        tempDirX <= (oldDirX * COS_OF_45 + oldDirY * NEG_SIN_OF_45);
                        tempDirY <= (oldDirX * SIN_OF_45 + oldDirY * COS_OF_45);
                    end else if (calculation_2) begin
                        calculation_2 <= 0;
                        tempPlaneX <= (oldPlaneX * COS_OF_45 + oldPlaneY * NEG_SIN_OF_45);
                        tempPlaneY <= (oldPlaneX * SIN_OF_45 + oldPlaneY * COS_OF_45);
                    end
                end
                else if (rightRot_pulse) begin
                    if (calculation_1) begin
                        calculation_1 <= 0;
                        calculation_2 <= 1;
                        tempPosX <= {8'b0, oldPosX, 8'b0};
                        tempPosY <= {8'b0, oldPosY, 8'b0};
                        tempDirX <=(oldDirX * COS_OF_45 + oldDirY * SIN_OF_45);
                        tempDirY <=(oldDirX * NEG_SIN_OF_45 + oldDirY * COS_OF_45);
                    end else if (calculation_2) begin
                        calculation_2 <= 0;
                        tempPlaneX <=(oldPlaneX * COS_OF_45 + oldPlaneY * SIN_OF_45);
                        tempPlaneY <=(oldPlaneX * NEG_SIN_OF_45 + oldPlaneY * COS_OF_45);
                    end
                end
            end
            else if (second_stage) begin
                second_stage <=0;
                posX <= tempPosX[23:8];
                posY <= tempPosY[23:8];
                dirX <= tempDirX[23:8];
                dirY <= tempDirY[23:8];
                planeX <= tempPlaneX[23:8];
                planeY <= tempPlaneY[23:8];
                //INPUT VALID
            end
        
        end
    end
    

endmodule