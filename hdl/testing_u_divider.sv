module testing_u_divider (
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [15:0] posX, //TODO change this in controloler to be a 31:0 value
  input wire [15:0] dirX,
  input wire [15:0] planeX,
  input wire [8:0] hcount_in, //which column I am calculating ray for on screen (0 to screenwidth-1), was thinking of incrementing in top_level and feedign that into dda
  output logic signed [15:0] rayDirX, //ray direction for the current column
  output logic stepX,      //direction in which the ray moves through the grid, for X and Y (-1 or 1)
  output logic [15:0] sideDistX,
  output logic [15:0] deltaDistX //distance to travel to reach the next x- or y-boundary
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

  typedef enum {RESTING, DIVIDING} divider_state;
  divider_state state;

  logic [23:0] fixed_pt_hcount; //Q12.12 representation of hcount
  assign fixed_pt_hcount = {{3'b0, hcount_in}, 12'b0};



  logic signed [47:0] cameraXMultiply; //is Q8.8 fixed point
  logic signed [31:0] cameraX;
  assign cameraXMultiply = ((fixed_pt_hcount * SCREEN_WIDTH_RECIPRICAL) << 1); // 2*x/w- 1
  assign cameraX = cameraXMultiply[39:8] + 32'b11111111111111110000000000000000;
  
  //might need to pipeline this multiplication once or twice

  logic div_busy;
  logic tabulate_in;
  logic valid_ray_calculated;

  

  logic start_rayDirX;
  logic busy_rayDirX;
  logic done_rayDirX;
  logic valid_rayDirX;
  logic ready_rayDirX;
  logic signed [15:0] rayX_recip_out;
  logic signed [31:0] tempSideDistX;

//   logic signed [31:0] tempPlaneX;
//   logic signed [31:0] tempPosX;
  logic signed [31:0] tempRayMultiply;
  logic signed [15:0] tempCameraX;

  logic signed [15:0] currentRayDirX;

  always_comb begin
    // tempPlaneX = $signed(planeX);
    // tempPosX = $signed(posX);
    // tempDirX = $signed(dirX);
    tempCameraX = $signed(cameraX[23:8]);
    tempRayMultiply = ($signed(planeX)*$signed(tempCameraX));
    rayDirX = $signed(dirX) + tempRayMultiply[23:8];
  end

  // logic start_rayDirY;
  // logic busy_rayDirY;
  // logic done_rayDirY;
  // logic valid_rayDirY;
  // logic [31:0] rayY_recip_out;



  //using divider module to calculate rayDir reciprocal
  divider #(.WIDTH(16), .FBITS(8)) rayX_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirX), .busy(busy_rayDirX), .done(done_rayDirX), 
  .valid(valid_rayDirX), .dbz(), .ovf(), .a(16'b0000_0001_0000_0000), .b(rayDirX), .val(rayX_recip_out));


  // divider #(.WIDTH(16), .FBITS(8)) rayY_recip (.clk_in(pixel_clk_in), .rst_in(rst_in), .start(start_rayDirY), .busy(busy_rayDirY), .done(done_rayDirY), 
  // .valid(valid_rayDirY), .dbz(rayY_0), .ovf(), .a(16'b0000_0001_0000_0000), .b(rayDirY), .val(rayY_recip_out));

  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
    //   rayDirX <= 0;
      currentRayDirX <= 0;
      stepX <= 0;
      sideDistX <= 0;
      deltaDistX <= 0;

      div_busy <= 0;
      tabulate_in <= 0; //triggering the divide

      start_rayDirX <= 0;
      ready_rayDirX <= 0;
      valid_ray_calculated <= 0;
      state <= RESTING;


    end else begin
      // cameraX with
          //ray direction calculation
          //TODO FIX MULTIPLICATION 
        //   rayDirX <= $signed(dirX) + tempRayMultiply[23:8];

          // // deltaDistX and deltaDistY based on rayDirX and rayDirY
          // //TODO: either implement divider module or use LUT
          // deltaDistX <= 1 / rayDirX; // ternary so no zero division - NEED LUT
          // //0 is 
          // deltaDistY <= 1 / rayDirY; //for abs need to jsut remove sign bit

          case(state)
            RESTING: begin
              if (~div_busy) begin
                if (valid_ray_calculated) begin //if raydirection is - in x
                    valid_ray_calculated <= 0;
                    if (rayDirX[15]) begin
                        stepX <= 0; //0 is -1 in x
                        // = posX - mapX
                        // sideDistX <= {8'b0, posX[7:0]} * $signed(deltaDistX); //mapX is the floor of posX
                        sideDistX <= tempSideDistX[23:8]; //mapX is the floor of posX
                    end else begin
                        stepX <= 1; // 1 is 1 in x
                        // = mapX - posX
                        sideDistX <= (~tempSideDistX[23:8]) + 16'b1111111100000000;
                    end 
                end else begin
                    start_rayDirX <= 1;
                    div_busy <= 1;
                    currentRayDirX <= rayDirX;
                    state <= DIVIDING;
                  end 
              end
            end
            DIVIDING: begin
              start_rayDirX <= 0;
              if (ready_rayDirX) begin
                  valid_ray_calculated <= 1;
                  ready_rayDirX<= 0;
                  div_busy <= 0;
                  tempSideDistX <= (({8'b0, posX[7:0]})) * $signed(deltaDistX);
                //   deltaDistX <= ~(rayX_recip_out) + 16'b0000_0001_0000_0000; //taking absolute value
                  state <= RESTING;
              end if (done_rayDirX) begin
                //TODO have intermediate registers with what current posX,Y etc are
                //   deltaDistX <= rayX_recip_out;
                  ready_rayDirX <= 1;
                  deltaDistX <= ~(rayX_recip_out) + 16'b0000_0001_0000_0000;
                  state <= DIVIDING;
              end
            end

          endcase
          // step direction and initial sideDist based on ray direction
          //TODO fix if statements
          
    end
  end
//BRAM instantiations for LUTs



endmodule