module movement_control #(
    parameter ROTATION_ANGLE = 16'b0010_1101_0000_0000 // default = 45 degrees
    )(input wire clk_in,
    input wire rst_in,
    input wire fwd_pulse, 
    input wire bwd_pulse, 
    input wire leftRot_pulse, 
    input wire rightRot_pulse,
    output logic [15:0] posX, 
    output logic [15:0] posY,
    output logic [15:0] dirX, 
    output logic [15:0] dirY,
    output logic [15:0] planeX, 
    output logic [15:0] planeY);

    localparam COS_OF_45 = 16'b0000000010110101; //cos(10) = 0.70703125 in FP
    localparam SIN_OF_45 = 16'b0000000010110101;
    localparam NEG_COS_OF_45 = 16'b1111111101001011;
    localparam NEG_SIN_OF_45 = 16'b1111111101001011;

    localparam MOVE_SPEED = 16'b0000_0001_0000_0000;
    localparam NEG_MOVE_SPEED = 16'b1111_1111_0000_0000;
    
    logic [31:0] tempDirX, tempDirY;
    logic [31:0] tempPosX, tempPosY;
    logic [31:0] tempPlaneX, tempPlaneY;

    always_comb begin
        tempPosX = {16'b0, posX};
        tempPosY = {16'b0, posY};
        tempDirX = {16'b0, dirX};
        tempDirY = {16'b0, dirY};
        tempPlaneX = {16'b0, planeX};
        tempPlaneY = {16'b0, planeY};
        if (fwd_pulse) begin
            tempPosX = tempPosX + (tempDirX * MOVE_SPEED);
            tempPosY = tempPosY + (tempDirY * MOVE_SPEED);
        end
        else if (bwd_pulse) begin
            tempPosX = tempPosX + (tempDirX * NEG_MOVE_SPEED);
            tempPosY = tempPosY + (tempDirY * NEG_MOVE_SPEED);
        end

        // Rotation logic
        else if (leftRot_pulse) begin
            tempDirX = (dirX * COS_OF_45 + dirY * NEG_SIN_OF_45);
            tempDirY = (dirX * SIN_OF_45 + dirY * COS_OF_45);
            tempPlaneX = (planeX * COS_OF_45 + planeY * NEG_SIN_OF_45);
            tempPlaneY = (planeX * SIN_OF_45 + planeY * COS_OF_45);
        end
        else if (rightRot_pulse) begin
            tempDirX = (dirX * COS_OF_45 + dirY * SIN_OF_45);
            tempDirY = (dirX * NEG_SIN_OF_45 + dirY * COS_OF_45);
            tempPlaneX = (planeX * COS_OF_45 + planeY * SIN_OF_45);
            tempPlaneY = (planeX * NEG_SIN_OF_45 + planeY * COS_OF_45);
        end
    end

    always_ff @(posedge clk_in) begin
        if (rst_in) begin //initial pos/orientation middle looking straight upward
            posX <= 16'b0000110010000000; //12.5
            posY <= 16'b0000110010000000;
            dirX <= 16'b0; //0
            dirY <= 16'b1111111100000000; //-1
            planeX <= 16'b0000000010101001;
            planeY <= 16'b0;
        end else begin
            posX <= tempPosX[23:8];
            posY <= tempPosY[23:8];
            dirX <= tempDirX[23:8];
            dirY <= tempDirY[23:8];
            planeX <= tempPlaneX[23:8];
            planeY <= tempPlaneY[23:8];
        end
    end
    

endmodule