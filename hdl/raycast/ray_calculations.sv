module ray_calculations (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [8:0] hcount_in, //which column I am calculating ray for on screen (0 to screenwidth-1), was thinking of incrementing in top_level and feedign that into dda
  input wire [15:0] posX, //TODO change this in controloler to be a 31:0 value
  input wire [15:0] posY,
  input wire [15:0] dirX,
  input wire [15:0] dirY,
  input wire [15:0] planeX,
  input wire [15:0] planeY,
  input wire dda_data_ready_out,
  output logic stepX,      //direction in which the ray moves through the grid, for X and Y (-1 or 1)
  output logic stepY,
  output logic signed [15:0] rayDirX, //ray direction for the current column
  output logic signed [15:0] rayDirY,
  output logic signed [15:0] sideDistX,
  output logic signed [15:0] sideDistY,
  output logic signed [15:0] deltaDistX, //distance to travel to reach the next x- or y-boundary
  output logic signed [15:0] deltaDistY,
  output logic ray_calc_busy,
  output logic valid_ray_out
  );
  localparam SCREEN_WIDTH = 320;
  localparam SCREEN_WIDTH_RECIPRICAL = 24'h00001A; //2*0.003173828125 = 0.00634765625 (24'h00001A)
  //fixed point representation: 0.003173828125
  //1/320 = .003125 
  // pos X & Y as outputs
  // cameraX, x-coordinate on the camera plane that the current x-coordinate of the screen represents,
  // right side of screen 1, center = 0, left side is -1
  // stepX - define whether the ray moves one grid cell left or right
  // in dda, stepX is used to add to mapX to check for wall hit, if not it checks which vector is longest?

  //TODO can I change the position for me to be posX and posY in fixed point for accuracy
  //and change mapX and mapY where player is integer wise in map

  typedef enum {RESTING, START, RAY_DIR_CALC, DIVIDING, DELTA_DIST_CALC, SIDE_DIST_CALC, VALID_OUT} ray_calculation_state;
  ray_calculation_state state;



  //might need to pipeline this multiplication once or twice

  logic div_busy;
  // logic tabulate_in;
  logic valid_ray_calculated;

  // logic [6:0] mapX, mapY;
  logic [7:0] mapX, mapY; // Extract the integer portion of posX and posY
  // logic [15:0] fracPosX, fracPosY; // Extract the fractional portion of posX and posY

  // assign mapX = posX[15:8]; // Integer part of posX
  // assign mapY = posY[15:8]; // Integer part of posY
  // assign fracPosX = posX[7:0]; // Fractional part of posX
  // assign fracPosY = posY[7:0]; // Fractional part of posY

  logic start_rayDirX;
  logic busy_rayDirX;
  logic done_rayDirX;
  logic valid_rayDirX;
  logic ready_rayDirX;
  logic overflow_rayDirX;
  logic signed [15:0] rayDirX_recip_out;
  logic signed [31:0] tempSideDistX;

  logic start_rayDirY;
  logic busy_rayDirY;
  logic done_rayDirY;
  logic valid_rayDirY;
  logic ready_rayDirY;
  logic overflow_rayDirY;
  logic signed [15:0] rayDirY_recip_out;
  logic signed [31:0] tempSideDistY;

  logic signed [31:0] tempRayDirXMultiply;
  logic signed [15:0] tempCameraX;

  logic signed [31:0] tempRayDirYMultiply;
  logic [15:0] full_mapX, full_mapY;

  // logic signed [15:0] currentRayDirX;
//   logic signed [15:0] currentRayDirY;

  logic [23:0] fixed_pt_hcount; //Q12.12 representation of hcount
  assign fixed_pt_hcount = {{3'b0, hcount_in}, 12'b0};


  logic [47:0] cameraXMultiply; //is Q8.8 fixed point, TODO: try Q2.
  logic signed [31:0] cameraX;
  assign cameraXMultiply = ((fixed_pt_hcount * SCREEN_WIDTH_RECIPRICAL)); // 2*x/w- 1 // (12.12)*(12.12)
  assign cameraX = $signed(cameraXMultiply[39:8]) + 32'shFFFF0000;
  //CHECK CAMERA X AT 49170000
  //+ 32'sb11111111111111110000000000000000 (IS MAKING CAMERA X NEGATIVE)
  // camera X = 0000f0 (0.003662109375) (without -1 in sim)
  // getting camera X = fffff080 (0.000244140625) (with -1 in sim) SHOULD BE fffff1
  //cameraX + 32'sb11111111111111110000000000000000
  // 000000_f08000 = .1111_0000_1101... in sim is 0.940673828125



  always_comb begin
    // tempCameraX = $signed(cameraX[23:8]);
    // tempRayDirXMultiply = ($signed(planeX)*$signed(tempCameraX));
    // rayDirX = $signed(dirX) + $signed(tempRayDirXMultiply[23:8]);

    // tempRayDirYMultiply = ($signed(planeY)*$signed(tempCameraX));
    // rayDirY = $signed(dirY) + $signed(tempRayDirYMultiply[23:8]);


    if (~stepX) begin
        // sideDistX = (posX - mapX) * deltaDistX;
        // Assuming mapX is the integer part of posX[15:8]
        mapX = posX[15:8];
        full_mapX = {mapX, 8'b0};
        tempSideDistX = ($signed(posX) - $signed(full_mapX)) * $signed(deltaDistX);
    end else begin
        // sideDistX = (mapX + 1.0 - posX) * deltaDistX;
        mapX = posX[15:8] + 1 ;
        full_mapX = {mapX, 8'b0};
        tempSideDistX = ($signed(full_mapX) - $signed(posX)) * $signed(deltaDistX);
    end

    if (~stepY) begin
        // sideDistY = (posY - mapY) * deltaDistY;
        mapY = posY[15:8];
        full_mapY = {mapY, 8'b0};
        tempSideDistY = ($signed(posY) - $signed(full_mapY)) * $signed(deltaDistY);
    end else begin
        // sideDistY = (mapY + 1.0 - posY) * deltaDistY;
        mapY = posY[15:8] + 1;
        full_mapY = {mapY, 8'b0};
        tempSideDistY = ($signed(full_mapY) - $signed(posY)) * $signed(deltaDistY);
    end

    // $display("Time: %0t | tempCameraX: %h", $time, tempCameraX);
    // $display("Time: %0t | tempRayDirXMultiply: %h, tempRayDirYMultiply: %h", $time, tempRayDirXMultiply, tempRayDirYMultiply);
    // $display("Time: %0t | tempSideDistX: %h, tempSideDistY: %h", $time, tempSideDistX, tempSideDistY);

    // busy_ray_calc = div_busy;
  end




  //using divider module to calculate rayDir reciprocal
  divider #(.WIDTH(16), .FBITS(8)) rayDirX_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirX), .busy(busy_rayDirX), .done(done_rayDirX), 
  .valid(valid_rayDirX), .dbz(), .ovf(overflow_rayDirX), .a(16'b0000_0001_0000_0000), .b(rayDirX), .val(rayDirX_recip_out));

  divider #(.WIDTH(16), .FBITS(8)) rayDirY_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirY), .busy(busy_rayDirY), .done(done_rayDirY), 
  .valid(valid_rayDirY), .dbz(), .ovf(overflow_rayDirY), .a(16'b0000_0001_0000_0000), .b(rayDirY), .val(rayDirY_recip_out));

  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      stepX <= 0;
      sideDistX <= 0;
      deltaDistX <= 0;
      rayDirX <=0;

      start_rayDirX <= 0;
      ready_rayDirX <= 0;

      stepY <= 0;
      sideDistY <= 0;
      deltaDistY <= 0;
      rayDirY <=0;

      start_rayDirY <= 0;
      ready_rayDirY <= 0;

      div_busy <= 0;      
      valid_ray_calculated <= 0;
      ray_calc_busy <= 0;
      state <= RESTING;
      valid_ray_out <= 0;

      tempRayDirXMultiply<=0;
      tempRayDirYMultiply<=0;


    end else begin
          case(state)
            RESTING: begin
              if (~ray_calc_busy) begin
                // start_rayDirX <= 1;
                // start_rayDirY <= 1;
                tempRayDirXMultiply <= ($signed(planeX)*$signed(cameraX[23:8]));
                tempRayDirYMultiply <= ($signed(planeY)*$signed(cameraX[23:8]));
                ray_calc_busy <= 1;
                state <= RAY_DIR_CALC;
              end
            end
            RAY_DIR_CALC: begin
              rayDirX <= $signed(dirX) + $signed(tempRayDirXMultiply[23:8]);
              rayDirY <= $signed(dirY) + $signed(tempRayDirYMultiply[23:8]);
              if (~div_busy) begin
                start_rayDirX <= 1;
                start_rayDirY <= 1;
                div_busy <= 1;
                state <= DIVIDING;
              end
            end
            DIVIDING: begin
              start_rayDirX <= 0;
              start_rayDirY <= 0;
              if (ready_rayDirX & ready_rayDirY) begin
                  valid_ray_calculated <= 1;
                  ready_rayDirX <= 0;
                  ready_rayDirY <= 0;
                  state <= DELTA_DIST_CALC;
              end if (done_rayDirX) begin
                //TODO have intermediate registers with what current posX,Y etc are
                  ready_rayDirX <= 1;
                  // deltaDistX <= rayDirX_recip_out;
                  deltaDistX <= (rayDirX_recip_out[15])?  ~(rayDirX_recip_out) + 16'b0000_0000_0000_0001: rayDirX_recip_out;
                  // $display("Time: %0t | deltaDistX (divider result): %d", $time, deltaDistX);
                  state <= DIVIDING;
              end if (done_rayDirY) begin
                  ready_rayDirY <= 1;
                  deltaDistY <= (rayDirY_recip_out[15])?  ~(rayDirY_recip_out) + 16'b0000_0000_0000_0001: rayDirY_recip_out;
                  // $display("Time: %0t | deltaDistY (divider result): %h", $time, deltaDistY);
                  state <= DIVIDING;
              end
            end
            DELTA_DIST_CALC: begin
                if (valid_ray_calculated) begin
                    valid_ray_calculated <= 0;
                    if (rayDirX[15]) begin //positive values of delta distance, need step/sidedist for DDA
                        stepX <= 0; //meaning this is negative 1
                        // deltaDistX <= ~(deltaDistX) + 16'b0000_0000_0000_0001; //twos complement of delta dis
                    end else begin
                        stepX <= 1; //meaning this is positive 1
                    end
                    if (rayDirY[15]) begin
                        stepY <= 0; //meaning this is negative 1
                        // deltaDistY <= ~(deltaDistY) + 16'b0000_0000_0000_0001; //twos complement of delta dis
                    end else begin
                        stepY <= 1; //meaning this is positive 1
                    end

                    state <= SIDE_DIST_CALC;
                end
            end
            SIDE_DIST_CALC: begin
                sideDistX <= tempSideDistX[23:8];  // Extracting bits 23 to 8 from tempSideDistX
                sideDistY <= tempSideDistY[23:8];
                // $display("Time: %0t | final deltaDistX: %h", $time, deltaDistX);
                // $display("Time: %0t | final deltaDistY: %h", $time, deltaDistY);
                // $display("Time: %0t | tempSideDistX: %h", $time, tempSideDistX);
                // $display("Time: %0t | tempSideDistY: %h", $time, tempSideDistY);
                // if (deltaDistX > 0 && deltaDistY > 0) begin
                //   sideDistX <= tempSideDistX[23:8];
                //   sideDistY <= tempSideDistY[23:8];
                // end else begin
                //   $display("Error: Invalid deltaDistX or deltaDistY values!");
                //   sideDistX <= 16'hFFFF;  // Set to max value to indicate an error
                //   sideDistY <= 16'hFFFF;
                // end 
                // sideDistX <= tempSideDistX[23:8];  // Extracting bits 23 to 8 from tempSideDistX
                // sideDistY <= tempSideDistY[23:8];
                state <= VALID_OUT;
                valid_ray_out <= 1;
            end
            VALID_OUT: begin
                // $display("Time: %0t | sideDistX: %h", $time, sideDistX);
                // $display("Time: %0t | sideDistY: %h", $time, sideDistY);

                  if (dda_data_ready_out) begin
                    valid_ray_out <= 0;
                    div_busy <= 1'b0;
                    ray_calc_busy <= 0;
                    state <= RESTING;

                  end
                end
          endcase
    end
  end
//BRAM instantiations for LUTs



endmodule