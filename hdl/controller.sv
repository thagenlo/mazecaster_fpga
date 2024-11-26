`default_nettype none 

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module controller #(parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 180, 
  parameter N = 24)
(
  input wire pixel_clk_in,
  input wire rst_in,
  input wire moveFwd,
  input wire moveBack,
  input wire rotLeft,
  input wire rotRight,
  input wire valid_in,
  output logic [15:0] posX, //exact location on map
  output logic [15:0] posY,
  output logic [15:0] dirX,
  output logic [15:0] dirY,
  output logic [15:0] planeX,
  output logic [15:0] planeY,
  output logic valid_out
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

  // logic moveFwd, moveBack;
  // logic rotLeft, rotRight;
  // logic [6:0] rotLeft, rotRight;
  // logic [7:0] mapX, mapY;
  // logic [15:0] posX, posY;
  // logic [15:0] dirX, dirY;
  // logic [32:0] planeX, planeY;
  // logic [31:0] newDirX, newDirY;
  // logic [31:0] newPosX, newPosY;
  // logic [31:0] newPlaneX, newPlaneY;
  // logic [$clog2(N*N)-1:0] map_addra; //(hcount_in - x_in) + ((vcount_in - y_in) * WIDTH);
  // logic [3:0] map_data;

  logic [31:0] tempDirX, tempDirY;
  logic [31:0] tempPosX, tempPosY;
  logic [31:0] tempPlaneX, tempPlaneY;

  always_comb begin
    // rotAngle = 10;
    // moveFwd = moveDir[1];
    // moveBack = moveDir[0];
    // rotLeft = rotDir[1];
    // rotRight = rotDir[0];

    // posX = pos[31:16];
    // posY = pos[15:0];
    // mapX = posX[15:8];
    // mapY = posY[15:8]; //rounded out to nearest int
    // mapY = (posY + (1 << 7)) >> 8;
    // map_addra = mapX+mapY*N;

    // dirX = newDirX[23:8]; //middle of dirX and dirY vectors
    // dirY = newDirY[23:8];
    // posX = newPosX[23:8];
    // posY = newPosY[23:8];
    // dirX = newDirX[23:8]; //middle of dirX and dirY vectors
    // dirY = newDirY[23:8];
    // planeX = newPlaneX[23:8]; //.66 -> 0.66015625
    // planeY = newPlaneY[23:8]; //.66 -> 0.66015625

    tempPosX = dirX * MOVE_SPEED;
    tempPosY = dirY * MOVE_SPEED;
    // tempDirX ; //middle of dirX and dirY vectors
    // tempDirY ;
    // tempPlaneX ; //.66 -> 0.66015625
    // tempPlaneY ; //.66 -> 0.66015625
    
  end
  //dirX and dirY indicate the direction the player is facing, a line extending out from the player's position into the screen
  //it guides center of camera view
  // planeX and planeY is the width of the camera view, this determines FOV (left and right screen boundaries) (wider FOV, longer plane vector = zoomed out, vice versa), will be scaled to dir in our case
  // makes it possible to calculate slightly different angles for each ray, making a view that stretches out from the center
  // rays in raycaster calculated by taking a point on camera plane and combining it with the direction vector

  //newDirX, can be intermediate combinationally set 16*16 bits -> 32 bits

  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      posX <=16'b0000110000000000;
      posY <= 0;
      dirX <= 0;
      dirY <= 16'b0000000100000000;
      planeX <= 16'b0; //.66 -> 0.66015625
      planeY <= 16'b0000000010101001; //.66 -> 0.66015625
      // newPosX <= 32'b00000000000101101000000000000000; 
      // newPosY <= 32'b00000000000000010000000000000000;
      // newDirX <= 0;
      // newDirY <= 32'b00000000000000010000000000000000;
      // newPlaneX <= 0;
      // newPlaneY <= 32'b00000000000000001010100011110110;

    end else begin

      // paddle_y <= (up && (paddle_y >= paddle_speed_in))? paddle_y - paddle_speed_in: 
      //                   (down && (paddle_y+PADDLE_HEIGHT+paddle_speed_in <= GAME_HEIGHT))? paddle_y + paddle_speed_in:
      //                   paddle_y;

      // if (puck_y <= puck_speed_in) begin
      //           dir_y <= 1'b1;
      //           puck_y <= puck_y + puck_speed_in;
      //       end else if (puck_y + PUCK_HEIGHT + puck_speed_in >= GAME_HEIGHT) begin
      //            dir_y <= 1'b0;
      //           puck_y <= puck_y - puck_speed_in;
      //       end else begin
      //            puck_y <= (dir_y)? puck_y + puck_speed_in: puck_y - puck_speed_in;
      //       end


      // if (moveFwd && (((posY + (dirY * MOVE_SPEED)) < N) && ((posY + (dirY * MOVE_SPEED)) >= 0))) begin
      //   //TODO: for accuracy may want to keep track of position update offset, so not just rounding to a whole number each movement
      //   if (map_data==0) begin
      //     // newPosX <= posX + (dirX * MOVE_SPEED);
      //     newPosY <= newPosY + (newDirY * MOVE_SPEED);
      //     //rounding properly could reduce error: ((dirY * MOVE_SPEED + (1 << 7)) >> 8)
      //   end
      // end
      // else if (moveBack && (((posY + (dirY * MOVE_SPEED)) < N) && ((posY + (dirY * MOVE_SPEED)) > 0))) begin
      //   if (map_data==0) begin
      //     // newPosX <= posX + (dirX * NEG_MOVE_SPEED);
      //     newPosY <= posY + (dirY * NEG_MOVE_SPEED);
      //   end
      // end

      if (valid_in) begin
        if (moveFwd) begin
          //TODO: for accuracy may want to keep track of position update offset, so not just rounding to a whole number each movement
          // if (map_data==0) begin
            posX <= posX + tempPosX[23:8];
            posY <= posY + tempPosY[23:8];
            valid_out <= 1;
            //rounding properly could reduce error: ((dirY * MOVE_SPEED + (1 << 7)) >> 8)
          // end
        end
        else if (moveBack) begin
          // if (map_data==0) begin
            posX <= posX + (~tempPosX[23:8] + 1'b1);
            posY <= posY + (~tempPosY[23:8] + 1'b1);
            valid_out <= 1;
          // end
        end
        // else if (rotLeft) begin
        //   //multiplying rot matrix by dir vector to have a rotated direction vector, pointing from player pos to screen,
        //   //(also doing this with plane vector to make sure it is always perpendicular to dir vector)
        //   newDirX <= (dirX * COS_ROT + dirY * SIN_ROT);
        //   newDirY <= (dirX * NEG_SIN_ROT + dirY * COS_ROT);
        //   newPlaneX <= (planeX * COS_ROT + planeY * SIN_ROT);
        //   newPlaneY <= (planeX * NEG_SIN_ROT + planeY * COS_ROT);
        //   //TODO: figure out if you can do this multiply here and just shift it by 8 (will need to make width of dirX bigger anyways)
        // end else if (rotRight) begin
        //   newDirX <= (dirX * COS_ROT + dirY * NEG_SIN_ROT);
        //   newDirY <= (dirX * SIN_ROT + dirY * COS_ROT);
        //   newPlaneX <= (planeX * COS_ROT + planeY * NEG_SIN_ROT);
        //   newPlaneY <= (planeX * SIN_ROT + planeY * COS_ROT);
        // end
        else begin
          valid_out <= 0;
        end
      end
    end
  end
    //NEED to get access to grid BRAM
    //to do any type of collision detection

  // xilinx_single_port_ram_read_first #(
  //   .RAM_WIDTH(4),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
  //   .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
  //   .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
  //   .INIT_FILE(`FPATH(grid_24x24_onlywall.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
  // ) worldMap (
  //   .addra(map_addra),     // Address bus, width determined from RAM_DEPTH
  //   .dina(0),       // RAM input data, width determined from RAM_WIDTH
  //   .clka(pixel_clk_in),       // Clock
  //   .wea(0),         // Write enable
  //   .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
  //   .rsta(rst_in),       // Output reset (does not affect memory contents)
  //   .regcea(1),   // Output register enable
  //   .douta(map_data)      // RAM output data, width determined from RAM_WIDTH
  // );


endmodule
`default_nettype wire