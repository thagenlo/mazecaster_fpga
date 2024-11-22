module ray_calculations (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [31:0] pos, //TODO change this in controloler to be a 31:0 value
  input wire [31:0] dir,
  input wire [31:0] plane,
  input wire [8:0] hcount_in, //which column I am calculating ray for on screen (0 to screenwidth-1), was thinking of incrementing in top_level and feedign that into dda
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

  typedef enum {RESTING, DIVIDING} divider_state;
  divider_state state;

  logic [15:0] posX, posY;
  logic [15:0] dirX, dirY;
  logic [15:0] planeX, planeY;
  logic [1:0] stepX, stepY;
  logic [15:0] cameraX; //is Q8.8 fixed point
  assign cameraX = (2 * hcount_in * SCREEN_WIDTH_RECIPRICAL) + 16'b1111_1111_0000_0000; // 2*x/w- 1

  logic div_busy;
  logic tabulate_in;

  logic start_rayDirX;
  logic busy_rayDirX;
  logic done_rayDirX;
  logic valid_rayDirX;
  logic [31:0] rayX_recip_out;

  logic [15:0] currentPosX;
  

  // logic start_rayDirY;
  // logic busy_rayDirY;
  // logic done_rayDirY;
  // logic valid_rayDirY;
  // logic [31:0] rayY_recip_out;



  //using divider module to calculate rayDir reciprocal
  u_divider #(.WIDTH(15), .FBITS(8)) rayX_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirX), .busy(busy_rayDirX), .done(done_rayDirX), 
  .valid(valid_rayDirX), .dbz(rayX_0), .ovf(), .a(15'b000_0001_0000_0000), .b(rayDirX[15:0]), .val(rayX_recip_out));


  // divider #(.WIDTH(16), .FBITS(8)) rayY_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirY), .busy(busy_rayDirY), .done(done_rayDirY), 
  // .valid(valid_rayDirY), .dbz(rayY_0), .ovf(), .a(16'b0000_0001_0000_0000), .b(rayDirY), .val(rayY_recip_out));

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

      div_busy <= 0;
      tabulate_in <= 0; //triggering the divide

      start_rayDirX <= 0;
      busy_rayDirX <= 0;
      done_rayDirX <= 0;
      valid_rayDirX <= 0;
      rayX_recip_out <= 0;
      state <= RESTING;


    end else begin
      // cameraX with
          //ray direction calculation
          //TODO FIX MULTIPLICATION 
          rayDirX <= dirX + ((planeX * cameraX));
          rayDirY <= dirY + ((planeY * cameraX));

          // // deltaDistX and deltaDistY based on rayDirX and rayDirY
          // //TODO: either implement divider module or use LUT
          // deltaDistX <= 1 / rayDirX; // ternary so no zero division - NEED LUT
          // //0 is 
          // deltaDistY <= 1 / rayDirY; //for abs need to jsut remove sign bit

          case(state)
            RESTING:
              if (~div_busy) begin
                if (tabulate_in) begin
                  start_rayDirX <= 1;
                  div_busy <= 1;
                  state <= DIVIDING;
                end
                  if (rayDirX[15] == 1) begin //if raydirection is - in x
                    stepX <= 0; //0 is -1 in x
                    // = posX - mapX
                    sideDistX <= {8'b0, posX[7:0]} * deltaDistX; //mapX is the floor of posX
                  end else begin
                    stepX <= 1; // 1 is 1 in x
                    // = mapX - posX
                    sideDistX <= {$signExtend(1), posX[7:0]} * deltaDistX;
                  end
                  if (rayDirY[15] == 1) begin //if raydirection is - in y
                    stepY <= 0;
                    sideDistY <= (posY - mapY) * deltaDistY;
                  end else begin
                    stepY <= 1;
                    sideDistY <= ((mapY + 1) << 8 - posY) * deltaDistY;
                  end
                end
            DIVIDING:
              start_rayDirX <= 0;
              if (x_valid_out && y_valid_out) begin
                  valid_out <= 1;
                  // x_valid_in <= 0;
                  // y_valid_in <= 0;
                  x_valid_out <= 0;
                  y_valid_out <= 0;
                  x_sum <= 0;
                  y_sum <= 0;
                  total_pixels <= 0;
                  x_out <= x_quotient_out;
                  y_out <= y_quotient_out;
                  div_busy <= 0;
                  state <= RESTING;
              end if (x_div_valid_out) begin
                  start_rayDirX <= 0;
                  done_rayDirX <= 1
                  deltaDistX <= rayX_recip_out;
                  state <= DIVIDING;
              end
              if (y_div_valid_out) begin
                  y_valid_in <= 0;
                  y_valid_out <= 1;
                  y_out <= y_quotient_out;
                  state <= DIVIDING;
              end


          endcase

          // if (~div_busy) begin
          //               if (tabulate_in && (total_pixels > 0)) begin
          //                   x_valid_in<= 1;
          //                   y_valid_in<= 1;
          //                   div_busy <= 1;
          //                   state <= DIVIDING;
          //               end else if (valid_in) begin
          //                   x_sum <= x_sum + x_in;
          //                   y_sum <= y_sum + y_in;
          //                   total_pixels <= total_pixels + 1;
          //                   state <= RESTING;
          //               end
          //           end

          if (~div_busy) begin
            if (tabulate_in) begin

            end
              if (rayDirX[15] == 1) begin //if raydirection is - in x
                stepX <= 0; //0 is -1 in x
                sideDistX <= (posX - mapX) * deltaDistX; //mapX is the floor of posX
              end else begin
                stepX <= 1; // 1 is 1 in x
                sideDistX <= ((mapX - posX))* deltaDistX;
              end
              if (rayDirY[15] == 1) begin //if raydirection is - in y
                stepY <= 0;
                sideDistY <= (posY - mapY) * deltaDistY;
              end else begin
                stepY <= 1;
                sideDistY <= ((mapY + 1) << 8 - posY) * deltaDistY;
              end
          end

          // step direction and initial sideDist based on ray direction
          //TODO fix if statements
          
    end
  end
//BRAM instantiations for LUTs



endmodule