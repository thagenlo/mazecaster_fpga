module dda
#(
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 240,
  parameter N = 24,
  parameter STACK_DEPTH = 16
  // parameter NUM_DDA_FSMS = 2
)
(
  input wire pixel_clk_in,
  input wire rst_in,
  input wire [119:0] dda_data_in, // (x_in, rayDir_in, sideDist_in, deltaDist_in, map_in) - (8 + (3*32) + 16) = 120
  input wire push_in,
  
  output logic [7:0] hcount_ray_out, //pipelined x_coord
  output logic [15:0] lineHeight_out, // = SCREEN_HEIGHT/perpWallDist
  output logic wallType_out, // 0 = X wall hit, 1 = Y wall hit
  output logic [7:0] mapData_out;  // value 0 -> 2^8 at map[mapX][mapY] from BROM
  output logic [15:0] wallX_out; //where on wall the ray hits

  output logic valid_out, // indicates when to store (x, lineHeight, wallType, mapData) in DDA_fifo_out
  
  );


  //TODO split up dda_data_in variables
  logic [7:0] x_in;
  //assign x_in = dda_data_in[119:112];
  logic [15:0] rayDirX, rayDirY, sideDistX, sideDistY, deltaDistX, deltaDistY;
  // assign rayDirX = rayDir_in[111:96];
  // assign rayDirY = rayDir_in[95:80];
  // assign sideDistX = sideDist_in[79:64];
  // assign sideDistY = sideDist_in[63:48];
  // assign deltaDistX = deltaDist_in[47:32];
  // assign deltaDistY = deltaDist_in[31:16];
  logic [15:0] map_in
  assign mapX = dda_data_in[15:8];
  assign mapY = dda_data_in[7:0];



  ////############ DDA FIFO ###############

  localparam FIFO_DEPTH = 128 // TODO

  // FIFO queue (array) and pointers
  logic [119:0] dda_fifo [FIFO_DEPTH-1:0];  // FIFO storage
  logic [$clog2(FIFO_DEPTH)-1:0] write_ptr; // write pointer
  logic [$clog2(FIFO_DEPTH)-1:0] read_ptr;  // read pointer
  logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count; // count num items in FIFO
  
  // handshaking & control signals
  logic dda_fsm0_ready, dda_fsm1_ready;
  logic dda_fsm0_busy, dda_fsm1_busy;
  logic dda_fsm0_valid_in, dda_fsm1_valid_in;
  logic [119:0] dda_fsm0_in, dda_fsm1_in;

  // PUSH logic (adding to fifo) 
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      write_ptr <= 0;
      fifo_count <= 0;
    end else if (push_in && fifo_count < FIFO_DEPTH) begin
      dda_fifo[write_ptr] <= dda_data_in;     // stores the incoming data
      write_ptr <= (write_ptr + 1) % FIFO_DEPTH; // increments & wrap write pointer
      fifo_count <= fifo_count + 1;           // updates item count
    end
  end

  // POP logic (removing from fifo) - (Only when FSM is ready and not busy)
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      read_ptr <= 0;
    end else begin
      if (!dda_fsm0_busy && fifo_count > 0) begin
        dda_fsm0_in <= dda_fifo[read_ptr];     // Provide data to FSM0
        dda_fsm0_valid_in <= 1'b1;             // Signal new data is valid for FSM0
        read_ptr <= (read_ptr + 1) % FIFO_DEPTH; // Increment and wrap read pointer
        fifo_count <= fifo_count - 1;          // Decrement count
      end else if (!dda_fsm1_busy && fifo_count > 0) begin
        dda_fsm1_in <= dda_fifo[read_ptr];     // Provide data to FSM1
        dda_fsm1_valid_in <= 1'b1;             // Signal new data is valid for FSM1
        read_ptr <= (read_ptr + 1) % FIFO_DEPTH; // Increment and wrap read pointer
        fifo_count <= fifo_count - 1;          // Decrement count
      end else begin
        dda_fsm0_valid_in <= 1'b0;
        dda_fsm1_valid_in <= 1'b0;
      end
    end
  end

  // output multiplexing based on valid_out signals from DDA FSMs
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      valid_out <= 0;
    end else begin
      if (dda_fsm0_valid_out) begin
        hcount_ray_out <= dda_fsm0_hcount_ray_out;
        lineHeight_out <= dda_fsm0_lineHeight_out;
        wallType_out <= dda_fsm0_wallType_out;
        mapData_out <= dda_fsm0_mapData_out;
        wallX_out <= dda_fsm0_wallX_out;
        valid_out <= 1;
      end else if (dda_fsm1_valid_out) begin
        hcount_ray_out <= dda_fsm1_hcount_ray_out;
        lineHeight_out <= dda_fsm1_lineHeight_out;
        wallType_out <= dda_fsm1_wallType_out;
        mapData_out <= dda_fsm1_mapData_out;
        wallX_out <= dda_fsm1_wallX_out;
        valid_out <= 1;
      end else begin
        valid_out <= 0;
      end
    end
  end


  ////############ DDA FSM MODULES ###############

  // DDA FSM module 0 HERE
  dda_fsm #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .N(N)
  ) dda_fsm0 (
    .pixel_clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .dda_data_in(dda_fsm0_in), //ADD
    .valid_in(dda_fsm0_valid_in), //ADD
    .ready_out(dda_fsm0_ready), //ADD
    // .hcount_ray_in(), REMOVE
    // .step_in(),  REMOVE
    // .rayDir_in(),  REMOVE
    // .sideDist_in(), REMOVE
    // .deltaDist_in(), REMOVE
    // .map_in(), REMOVE

    // .ready_in(), REMOVE

    .map_data(),
    .map_data_ready(),
    .map_addra(),
    .map_request(),

    .hcount_ray_out(dda_fsm0_hcount_ray_out),
    .lineHeight_out(dda_fsm0_lineHeight_out),
    .wallType_out(dda_fsm0_wallType_out),
    .mapData_out(dda_fsm0_mapData_out),
    .wallX_out(dda_fsm0_wallX_out),
    
    .busy_out(dda_fsm0_busy),
    .valid_out(dda_fsm0_valid_out)
  );

  // DDA FSM module 1 HERE (duplicate when ready)


  //if pop0 / DDA_fsm_0_ready_out - store to dda_out_stack HERE
  //if pop1 / DDA_fsm_1_ready_out - store to dda_out_stack HERE

  //always_ff -> while dda_out_stack pointer >=0, output dda_out_stack, valid_out, and pointer -1


  ////############ MAP DATA BRAM REQUESTS ###############

  // signals for map data requests from each submodule
  logic dda_fsm0_map_request, dda_fsm1_map_request;
  logic [$clog2(N*N)-1:0] dda_fsm0_map_addra, dda_fsm1_map_addra;
  
  // arbiter state and control signals
  typedef enum logic [1:0] {IDLE, GRANT_FSM0, GRANT_FSM1} arbiter_state_t;
  arbiter_state_t arbiter_state;

  // arbiter logic
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      arbiter_state <= IDLE;
      map_request <= 1'b0;
    end else begin
      case (arbiter_state)
        IDLE: begin
          if (dda_fsm0_map_request) begin
            arbiter_state <= GRANT_FSM0;
            map_addra <= dda_fsm0_map_addra;
            map_request <= 1'b1;
          end else if (dda_fsm1_map_request) begin
            arbiter_state <= GRANT_FSM1;
            map_addra <= dda_fsm1_map_addra;
            map_request <= 1'b1;
          end else begin
            map_request <= 1'b0; // No request
          end
        end
        
        GRANT_FSM0: begin
          if (map_data_ready) begin
            arbiter_state <= IDLE;
            map_request <= 1'b0;
          end
        end

        GRANT_FSM1: begin
          if (map_data_ready) begin
            arbiter_state <= IDLE;
            map_request <= 1'b0;
          end
        end
      endcase
    end
  end

  // connect BRAM data to the appropriate FSM based on arbiter state
  always_ff @(posedge pixel_clk_in) begin
    if (map_data_ready) begin
      if (arbiter_state == GRANT_FSM0) begin
        dda_fsm0_map_data <= map_data; // Provide map data to FSM0
        dda_fsm0_map_data_ready <= 1'b1;
      end else if (arbiter_state == GRANT_FSM1) begin
        dda_fsm1_map_data <= map_data; // Provide map data to FSM1
        dda_fsm1_map_data_ready <= 1'b1;
      end
    end else begin
      dda_fsm0_map_data_ready <= 1'b0;
      dda_fsm1_map_data_ready <= 1'b0;
    end
  end




  // logic [$clog2(N*N)-1:0] map_addra;
  // assign map_addra = // TODO (hcount_in - x_in) + ((vcount_in - y_in) * WIDTH);

  // logic [7:0] map_data; //based on RAM_WIDTH (how many map numbers we want)


  //  2D MAP - Xilinx Single Port Read First RAM
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