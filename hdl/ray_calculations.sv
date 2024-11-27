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
  input wire start_ray_calc,
  input wire dda_data_ready_out,
  output logic stepX,      //direction in which the ray moves through the grid, for X and Y (-1 or 1)
  output logic stepY,
  output logic signed [15:0] rayDirX, //ray direction for the current column
  output logic signed [15:0] rayDirY,
  output logic [15:0] sideDistX,
  output logic [15:0] sideDistY,
  output logic [15:0] deltaDistX, //distance to travel to reach the next x- or y-boundary
  output logic [15:0] deltaDistY,
  output logic [8:0] hcount_out,
  output logic busy_ray_calc,
  output logic valid_ray_out
  );
  localparam SCREEN_WIDTH = 320;
  localparam SCREEN_WIDTH_RECIPRICAL = 24'b0000_0000_0000_0000_0000_1101; //fixed point representation: 0.003173828125
  //1/320 = .003125 
  // pos X & Y as outputs
  // cameraX, x-coordinate on the camera plane that the current x-coordinate of the screen represents,
  // right side of screen 1, center = 0, left side is -1
  // stepX - define whether the ray moves one grid cell left or right
  // in dda, stepX is used to add to mapX to check for wall hit, if not it checks which vector is longest?

  //TODO can I change the position for me to be posX and posY in fixed point for accuracy
  //and change mapX and mapY where player is integer wise in map

  typedef enum {RESTING, START, DIVIDING, DELTA_DIST_CALC, SIDE_DIST_CALC, VALID_OUT} divider_state;
  divider_state state;

  logic [23:0] fixed_pt_hcount; //Q12.12 representation of hcount
  assign fixed_pt_hcount = {{3'b0, hcount_in}, 12'b0};



  logic signed [47:0] cameraXMultiply; //is Q8.8 fixed point, TODO: try Q2.
  logic signed [31:0] cameraX;
  assign cameraXMultiply = ((fixed_pt_hcount * SCREEN_WIDTH_RECIPRICAL) << 1); // 2*x/w- 1 // (12.12)*(12.12)
  assign cameraX = cameraXMultiply[39:8] + 32'b11111111111111110000000000000000;
  
  //might need to pipeline this multiplication once or twice

  logic div_busy;
  // logic tabulate_in;
  logic valid_ray_calculated;

  logic [6:0] mapX, mapY;
  // logic [15:0] posX, posY;
  // logic [15:0] dirX, dirY;
  // logic [32:0] planeX, planeY;

  logic start_rayDirX;
  logic busy_rayDirX;
  logic done_rayDirX;
  logic valid_rayDirX;
  logic ready_rayDirX;
  logic signed [15:0] rayDirX_recip_out;
  logic signed [31:0] tempSideDistX;

  logic start_rayDirY;
  logic busy_rayDirY;
  logic done_rayDirY;
  logic valid_rayDirY;
  logic ready_rayDirY;
  logic signed [15:0] rayDirY_recip_out;
  logic signed [31:0] tempSideDistY;

//   logic signed [31:0] tempPlaneX;
//   logic signed [31:0] tempPosX;
  logic signed [31:0] tempRayDirXMultiply;
  logic signed [15:0] tempCameraX;

  logic signed [31:0] tempRayDirYMultiply;

  // logic signed [15:0] currentRayDirX;
//   logic signed [15:0] currentRayDirY;

  always_comb begin
    tempCameraX = $signed(cameraX[23:8]);
    tempRayDirXMultiply = ($signed(planeX)*$signed(tempCameraX));
    rayDirX = $signed(dirX) + tempRayDirXMultiply[23:8];

    tempRayDirYMultiply = ($signed(planeY)*$signed(tempCameraX));
    rayDirY = $signed(dirY) + tempRayDirYMultiply[23:8];

    // abs_posX = (posX[15])? (~(posX) + 16'b0000_0000_0000_0001): posX;
    
    tempSideDistX = (~stepX)? ({8'b0, posX[7:0]}) * $signed(deltaDistX): (({posX[15:8], 8'b0}) + 16'b0000_0001_0000_0000 - posX) * $signed(deltaDistX);
    tempSideDistY = (~stepY)? ({8'b0, posY[7:0]}) * $signed(deltaDistY): (({posY[15:8], 8'b0}) + 16'b0000_0001_0000_0000 - posY) * $signed(deltaDistY);

    busy_ray_calc = div_busy;
  end




  //using divider module to calculate rayDir reciprocal
  divider #(.WIDTH(16), .FBITS(8)) rayDirX_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirX), .busy(busy_rayDirX), .done(done_rayDirX), 
  .valid(valid_rayDirX), .dbz(), .ovf(), .a(16'b0000_0001_0000_0000), .b(rayDirX), .val(rayDirX_recip_out));

  divider #(.WIDTH(16), .FBITS(8)) rayDirY_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirY), .busy(busy_rayDirY), .done(done_rayDirY), 
  .valid(valid_rayDirY), .dbz(), .ovf(), .a(16'b0000_0001_0000_0000), .b(rayDirY), .val(rayDirY_recip_out));

  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
    //   rayDirX <= 0;
      // currentRayDirX <= 0;
      stepX <= 0;
      sideDistX <= 0;
      deltaDistX <= 0;

      start_rayDirX <= 0;
      ready_rayDirX <= 0;

    //   currentRayDirY <= 0;
      stepY <= 0;
      sideDistY <= 0;
      deltaDistY <= 0;

      start_rayDirY <= 0;
      ready_rayDirY <= 0;

      div_busy <= 0;
      // tabulate_in <= 0; //triggering the divide
      
      valid_ray_calculated <= 0;
      state <= RESTING;
      valid_ray_out <= 0;


    end else begin
          case(state)
            RESTING: begin
              if (~div_busy) begin
                valid_ray_out <= 0;
                start_rayDirX <= 1;
                start_rayDirY <= 1;
                // currentRayDirY <= rayDirY;
                // currentRayDirX <= rayDirX;
                div_busy <= 1;
                state <= DIVIDING;
              end
            end
            DIVIDING: begin
              start_rayDirX <= 0;
              start_rayDirY <= 0;
              if (ready_rayDirX & ready_rayDirY) begin
                  valid_ray_calculated <= 1;
                  // div_busy <= 0;
                  ready_rayDirX <= 0;
                  ready_rayDirY <= 0;
                //   tempSideDistX <= (({8'b0, posX[7:0]})) * $signed(deltaDistX);
                //   tempSideDistY <= (({8'b0, posY[7:0]})) * $signed(deltaDistY);
                //   deltaDistX <= ~(rayX_recip_out) + 16'b0000_0001_0000_0000; //taking absolute value
                  
                  state <= DELTA_DIST_CALC;
              end if (done_rayDirX) begin
                //TODO have intermediate registers with what current posX,Y etc are
                  ready_rayDirX <= 1;
                  deltaDistX <= rayDirX_recip_out;
                  state <= DIVIDING;
              end if (done_rayDirY) begin
                  ready_rayDirY <= 1;
                  deltaDistY <= rayDirY_recip_out;
                  state <= DIVIDING;
              end
            end
            DELTA_DIST_CALC: begin
                if (valid_ray_calculated) begin //if raydirection is - in x
                    valid_ray_calculated <= 0;
                    if (deltaDistX[15]) begin //positive values of delta distance, need step/sidedist for DDA
                        stepX <= 0; //meaning this is negative 1
                        deltaDistX <= ~(deltaDistX) + 16'b0000_0000_0000_0001; //twos complement of delta dis
                        // tempSideDistX <= (({8'b0, posX[7:0]})) * $signed(deltaDistX);
                        // sideDistX <= tempSideDistX[23:8]; //mapX is the floor of posX
                    end else begin
                        stepX <= 1; //meaning this is positive 1
                        // sideDistX <= (~tempSideDistY[23:8]) + 16'b0000_0000_0000_0001;
                        // tempSideDistX <= (({posX[15:8], 8'b0}) + 16'b0000_0001_0000_0000) * $signed(deltaDistX);
                    end
                    if (deltaDistY[15]) begin
                        stepY <= 0; //meaning this is negative 1
                        deltaDistY <= ~(deltaDistY) + 16'b0000_0000_0000_0001; //twos complement of delta dis
                    end else begin
                        stepY <= 1; //meaning this is positive 1
                    end

                    // if (rayDirY[15]) begin
                    //     stepY <= 0;
                    //     sideDistY <= tempSideDistY[23:8];
                    // end else begin
                    //     stepX <= 1;
                    //     sideDistY <= (~tempSideDistY[23:8]) + 16'b1111111100000000;
                    // end 
                    state <= SIDE_DIST_CALC;
                end
            end
            SIDE_DIST_CALC: begin
                // if (~stepX) begin //if stepX is -1
                //     tempSideDistX <= ({8'b0, posX[7:0]}) * $signed(deltaDistX); //sideDistX = (posX - mapX) * deltaDistX;
                //     // sideDistX <= tempSideDistX[23:8]; //mapX is the floor of posX
                // end else begin //if stepX is +1
                //     tempSideDistX <= (({posX[15:8], 8'b0}) + 16'b0000_0001_0000_0000 - posX) * $signed(deltaDistX); //sideDistX = (mapX + 1.0 - posX) * deltaDistX;
                // end
                sideDistX <= tempSideDistX[23:8];
                sideDistY <= tempSideDistY[23:8];
                hcount_out <= hcount_in;
                state <= VALID_OUT;
            end
            VALID_OUT: begin
                valid_ray_out <= 1;
                  if (dda_data_ready_out) begin
                    // data is not sent to the FIFO unless dda_data_ready_out is high
                    // sideDistX <= tempSideDistX[23:8];
                    // valid_ray_out <= 1'b1;
                    div_busy <= 1'b0;
                    state <= RESTING;
                  end
                end
          endcase
    end
  end
//BRAM instantiations for LUTs



endmodule