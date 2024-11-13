module controller (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [1:0] moveDir, //fwd, back
  input wire [1:0] rotDir, //left, right
  output wire [13:0] pos,
  output wire [31:0] dir,
  output wire [15:0] plane,
  );
  localparam SCREEN_WIDTH = 320;
  localparam FOV = 66; // 66 degrees
  localparam ROT_COS = 16'b0000_0000_1111_1100; //rotation matrix cos val, rotating by a fixed 10 degrees
  localparam ROT_SIN = 16'b0000_0000_0010_1100; //rotation matrix sin val, rotating by a fixed 10 degrees
  // can make fractional bit longer for more accuracy
  // cos(10) = 0.984808 , 0b0000_0000_1111_1100 (0.96875)
  // sin(10) = 0.173648 , 0b0000_0000_0010_1100 (0.171875)
  localparam MOVE_SPEED = 1;//TODO figure out what a reasonable move speed is
  
  logic moveFwd, moveBack;
  logic rotLeft, rotRight;
  logic [6:0] posX, [6:0] posY;
  logic [31:16] dirX, [15:0] dirY;
  logic [31:0] planeX, [15:0] plane;
  assign rotAngle = 10;
  assign moveFwd = moveDir[1];
  assign moveBack = moveDir[0];
  assign rotLeft = rotDir[1];
  assign rotRight = rotDir[0];
  //dirX and dirY indicate the direction the player is facing, a line extending out from the player's position into the screen
  //it guides center of camera view
  // planeX and planeY is the width of the camera view, this determines FOV (left and right screen boundaries) (wider FOV, longer plane vector = zoomed out, vice versa), will be scaled to dir in our case
  // makes it possible to calculate slightly different angles for each ray, making a view that stretches out from the center
  // rays in raycaster calculated by taking a point on camera plane and combining it with the direction vector

  //newDirX, can be intermediate combinationally set 16*16 bits -> 32 bits

  always_ff @(posEdge pixel_clk_in) begin
    if (rst_in) begin
      posX <= 12;
      posY <= 0;
      dirX <= 0;
      dirY <= 1;
      planeX <= 16'b0; //.66 -> 0.66015625
      planeY <= 16'b0000000010101001; //.66 -> 0.66015625

    end else begin
      if (moveFwd && ((posY < 89) && (posY >= 0))) begin

        //TODO: for accuracy may want to keep track of position update offset, so not just rounding to a whole number each movement
        if (worldMap[posX][posY-1]==0) begin
          posY <= posY + ((dirY * MOVE_SPEED + (1 << 7)) >> 8);
        end
      end

      else if (moveBack && ((posY < 90) && (posY > 0))) begin
        if (worldMap[posY][posY-1]==0) begin 
          posY <= posY + ((dirY * MOVE_SPEED + (1 << 7)) >> 8);
        end
      end
      else if (rotLeft) begin
        //multiplying rot matrix by dir vector to have a rotated direction vector, pointing from player pos to screen,
        //(also doing this with plane vector to make sure it is always perpendicular to dir vector)
        dirX <= (dirX * COS_ROT + dirY * SIN_ROT) >> 8;
        dirY <= (-dirX * SIN_ROT + dirY * COS_ROT) >> 8;
        planeX <= (planeX * COS_ROT + planeY * SIN_ROT) >> 8;
        planeY <= (-planeX * SIN_ROT + planeY * COS_ROT) >> 8;
        //TODO: figure out if you can do this multiply here and just shift it by 8 (will need to make width of dirX bigger anyways)
      
      end else if (rotRight) begin
        dirX <= (dirX * COS_ROT - dirY * SIN_ROT) >> 8;
        dirY <= (dirX * SIN_ROT + dirY * COS_ROT) >> 8;
        planeX <= (planeX * COS_ROT - planeY * SIN_ROT) >> 8;
        planeY <= (planeX * SIN_ROT + planeY * COS_ROT) >> 8;
      
      end

    end
  end
  //NEED to get access to grid BRAM
  //to do any type of collision detection

endmodule