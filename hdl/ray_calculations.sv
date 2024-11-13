module ray_calculations (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [13:0] pos, //TODO change this in controloler to be a 31:0 value
  input wire [31:0] dir,
  input wire [15:0] plane,
  input wire hcount_in[8:0], //which column I am calculating ray for on screen (0 to screenwidth-1), was thinking of incrementing in top_level and feedign that into dda
  output wire [15:0] rayDirX, //ray direction for the current column
  output wire [15:0] rayDirY,
  output wire stepX, stepY,      //direction in which the ray moves through the grid, for X and Y (-1 or 1)
  output wire [15:0] sideDistX, sideDistY,
  output wire [15:0] deltaDistX, deltaDistY //distance to travel to reach the next x- or y-boundary
  );
  localparam SCREEN_WIDTH = 320;
  localparam SCREEN_WIDTH_RECIPRICAL = 16'b0000000000000001; //fixed point representation: 0.00390625
  //1/320 = .003125 
  // pos X & Y as outputs
  // cameraX, x-coordinate on the camera plane that the current x-coordinate of the screen represents,
  // right side of screen 1, center = 0, left side is -1
  // stepX - define whether the ray moves one grid cell left or right
  // in dda, stepX is used to add to mapX to check for wall hit, if not it checks which vector is longest?

  //TODO can I change the position for me to be posX and posY in fixed point for accuracy
  //and change mapX and mapY where player is integer wise in map

  logic moveFwd, moveBack;
  logic rotLeft, rotRight;
  logic [6:0] posX, [6:0] posY;
  logic [15:0] dirX, [15:0] dirY;
  logic [15:0] planeX, [15:0] planeY;
  logic [1:0] stepX, stepY;
  logic signed [15:0] cameraX;
  assign cameraX = ((2 * hcount_in) * SCREEN_WIDTH_RECIPRICAL) - 1;
  always_ff @(posEdge pixel_clk_in) begin
    if (rst_in) begin
      rayDirX <= 0;
      rayDirY <= 0;
      stepX <= 0;
      stepY <= 0;
      sideDistX <= 1;
      sideDistY <= 1;
      deltaDistX <= 0;
      deltaDistY <= 0;
    end else begin
      // cameraX with
          //ray direction calculation
          //TODO FIX MULTIPLICATION
          rayDirX <= dirX + ((planeX * cameraX));
          rayDirY <= dirY + ((planeY * cameraX));

          // deltaDistX and deltaDistY based on rayDirX and rayDirY
          //TODO: either implement divider module or use LUT
          deltaDistX <= 1 / rayDirX[14:0]; // ternary so no zero division - NEED LUT
          //0 is 
          deltaDistY <= 1 / rayDirY[14:0]; //for abs need to jsut remove sign bit

          // step direction and initial sideDist based on ray direction
          if (rayDirX < 0) begin
              stepX <= 0; //0 is
              sideDistX <= (posX - mapX) * deltaDistX;
          end else begin
              stepX <= 1;
              sideDistX <= ((mapX + 1) << 8 - posX) * deltaDistX;
          end
          if (rayDirY < 0) begin
              stepY <= 0;
              sideDistY <= (posY - mapY) * deltaDistY;
          end else begin
              stepY <= 1;
              sideDistY <= ((mapY + 1) << 8 - posY) * deltaDistY;
          end
    end
  end
//BRAM instantiations for LUTs



endmodule