`default_nettype none 

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module controller (parameter N = 24,
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_WIDTH = 240)
(
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [1:0] moveDir, //fwd, back
  input wire [1:0] rotDir, //left, right
  output logic [31:0] pos, //exact location on map
  output logic [31:0] dir,
  output logic [31:0] plane
  );
  //localparam SCREEN_WIDTH = 320;
  localparam FOV = 66; // 66 degrees
  localparam COS_ROT = 16'b0000_0000_1111_1100; //rotation matrix cos val, rotating by a fixed 10 degrees
  localparam SIN_ROT = 16'b0000_0000_0010_1100; //rotation matrix sin val, rotating by a fixed 10 degrees
  localparam NEG_SIN_ROT = 16'b1111_1111_1101_0100;
  // can make fractional bit longer for more accuracy
  // cos(10) = 0.984808 , 0b0000_0000_1111_1100 (0.96875)
  // sin(10) = 0.173648 , 0b0000_0000_0010_1100 (0.171875)
  localparam MOVE_SPEED = 16'b0000_0001_0000_0000;//TODO figure out what a reasonable move speed is
  localparam NEG_MOVE_SPEED = 16'b1111_1111_0000_0000;

  logic moveFwd, moveBack;
  // logic rotLeft, rotRight;
  logic [6:0] rotLeft, rotRight;
  logic [6:0] mapX, mapY;
  logic [15:0] posX, posY;
  logic [15:0] dirX, dirY;
  logic [32:0] planeX, planeY;
  logic [32:0] newDirX, newDirY;
  logic [32:0] newPosX, newPosY;
  logic [32:0] newPlaneX, newPlaneY;

  always_comb begin
    // rotAngle = 10;
    moveFwd = moveDir[1];
    moveBack = moveDir[0];
    rotLeft = rotDir[1];
    rotRight = rotDir[0];

    posX = pos[31:16];
    posY = pos[15:0];
    mapX = (posX + (1 << 7)) >> 8; //rounded out to nearest int
    mapY = (posY + (1 << 7)) >> 8;

    dirX = newDirX[23:8]; //middle of dirX and dirY vectors
    dirY = newDirY[23:8];
  end
  //dirX and dirY indicate the direction the player is facing, a line extending out from the player's position into the screen
  //it guides center of camera view
  // planeX and planeY is the width of the camera view, this determines FOV (left and right screen boundaries) (wider FOV, longer plane vector = zoomed out, vice versa), will be scaled to dir in our case
  // makes it possible to calculate slightly different angles for each ray, making a view that stretches out from the center
  // rays in raycaster calculated by taking a point on camera plane and combining it with the direction vector

  //newDirX, can be intermediate combinationally set 16*16 bits -> 32 bits

  always_ff @(posedge pixel_clk_in) begin
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
        if (worldMap[posY*N+posX-1]==0) begin
          newPosX <= posX + (dirX * MOVE_SPEED);
          newPosY <= posY + (dirY * MOVE_SPEED);
          //rounding properly could reduce error: ((dirY * MOVE_SPEED + (1 << 7)) >> 8)
        end
      end

      else if (moveBack && ((posY < 90) && (posY > 0))) begin
        if (worldMap[posY*N+posX-1]==0) begin
          newPosX <= posX + (dirX * NEG_MOVE_SPEED);
          newPosY <= posY + (dirY * NEG_MOVE_SPEED);
        end
      end
      else if (rotLeft) begin
        //multiplying rot matrix by dir vector to have a rotated direction vector, pointing from player pos to screen,
        //(also doing this with plane vector to make sure it is always perpendicular to dir vector)
        newDirX <= (dirX * COS_ROT + dirY * SIN_ROT);
        newDirY <= (dirX * NEG_SIN_ROT + dirY * COS_ROT);
        newPlaneX <= (planeX * COS_ROT + planeY * SIN_ROT);
        newPlaneY <= (planeX * NEG_SIN_ROT + planeY * COS_ROT);
        //TODO: figure out if you can do this multiply here and just shift it by 8 (will need to make width of dirX bigger anyways)
      end else if (rotRight) begin
        newDirX <= (dirX * COS_ROT + dirY * NEG_SIN_ROT);
        newDirY <= (dirX * SIN_ROT + dirY * COS_ROT);
        newPlaneX <= (planeX * COS_ROT + planeY * NEG_SIN_ROT);
        newPlaneY <= (planeX * SIN_ROT + planeY * COS_ROT);
      end
    end
  end
  //NEED to get access to grid BRAM
  //to do any type of collision detection

  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^8)
    .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(map.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
  ) worldMap (
    .addra(map_addra),     // Address bus, width determined from RAM_DEPTH
    .dina(0),       // RAM input data, width determined from RAM_WIDTH
    .clka(pixel_clk_in),       // Clock
    .wea(0),         // Write enable
    .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    .rsta(rst_in),       // Output reset (does not affect memory contents)
    .regcea(1),   // Output register enable
    .douta(map_data)      // RAM output data, width determined from RAM_WIDTH
  );


endmodule
`default_nettype wire