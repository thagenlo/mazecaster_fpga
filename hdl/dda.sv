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
  input wire [] dda_data_in, // (hcount_ray, rayDir_in, sideDist_in, deltaDist_in, map_in) - (8 + (3*32) + 16) = 120
  input wire push_in,
  
  output logic [8:0] hcount_ray_out, //pipelined x_coord
  output logic [15:0] lineHeight_out, // = SCREEN_HEIGHT/perpWallDist
  output logic wallType_out, // 0 = X wall hit, 1 = Y wall hit
  output logic [3:0] mapData_out;  // value 0 -> 2^4 at map[mapX][mapY] from BROM
  output logic [15:0] wallX_out; //where on wall the ray hits

  output logic valid_out, // indicates when to store (x, lineHeight, wallType, mapData) in DDA_fifo_out
  
  );


  ////############ DDA FIFO ###############

  localparam FIFO_DEPTH = 128 // TODO

  // FIFO queue (array) and pointers
  logic [119:0] dda_fifo [FIFO_DEPTH-1:0];  // FIFO storage
  logic [$clog2(FIFO_DEPTH)-1:0] write_ptr; // write pointer
  logic [$clog2(FIFO_DEPTH)-1:0] read_ptr;  // read pointer
  logic [$clog2(FIFO_DEPTH+1)-1:0] fifo_count; // count num items in FIFO
  
  // handshaking & control signals
  logic dda_fsm0_busy, dda_fsm1_busy;
  logic dda_fsm0_valid_in, dda_fsm1_valid_in;
  logic [119:0] dda_fsm0_in, dda_fsm1_in;
  logic dda_fsm0_valid_out, dda_fsm1_valid_out;

  // PUSH logic (adding to fifo) 
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      write_ptr <= 0;
      fifo_count <= 0;
    end else if (push_in && fifo_count < FIFO_DEPTH) begin
      dda_fifo[write_ptr] <= dda_data_in;     // stores the incoming data
      write_ptr <= (write_ptr + 1 == FIFO_DEPTH) ? 0 : write_ptr + 1; // increments & wrap write pointer
      fifo_count <= fifo_count + 1;           // updates item count
    end
  end

  // POP logic (removing from fifo) - (only when FSM is ready and not busy)
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      read_ptr <= 0;
      dda_fsm0_valid_in <= 1'b0;
      dda_fsm1_valid_in <= 1'b0;
      dda_fsm0_in <= 0;
      dda_fsm1_in <= 0;
    end else begin
      if (!dda_fsm0_busy && fifo_count > 0) begin
        dda_fsm0_in <= dda_fifo[read_ptr];     // provide data to FSM0
        dda_fsm0_valid_in <= 1'b1;             // signal new data is valid for FSM0
        read_ptr <= (read_ptr + 1 == FIFO_DEPTH) ? 0 : read_ptr + 1; // increment and wrap read pointer
        fifo_count <= fifo_count - 1;          // decrement count
      end else if (!dda_fsm1_busy && fifo_count > 0) begin
        dda_fsm1_in <= dda_fifo[read_ptr];     // provide data to FSM1
        dda_fsm1_valid_in <= 1'b1;             // signal new data is valid for FSM1
        read_ptr <= (read_ptr + 1 == FIFO_DEPTH) ? 0 : read_ptr + 1; // increment and wrap read pointer
        fifo_count <= fifo_count - 1;          // decrement count
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
      if (dda_fsm0_valid_out) begin //single cycle valid out
        hcount_ray_out <= dda_fsm0_hcount_ray_out;
        lineHeight_out <= dda_fsm0_lineHeight_out;
        wallType_out <= dda_fsm0_wallType_out;
        mapData_out <= dda_fsm0_mapData_out;
        wallX_out <= dda_fsm0_wallX_out;
        valid_out <= 1'b1;
      end else if (dda_fsm1_valid_out) begin //single cycle valid out
        hcount_ray_out <= dda_fsm1_hcount_ray_out;
        lineHeight_out <= dda_fsm1_lineHeight_out;
        wallType_out <= dda_fsm1_wallType_out;
        mapData_out <= dda_fsm1_mapData_out;
        wallX_out <= dda_fsm1_wallX_out;
        valid_out <= 1'b1;
      end else begin
        valid_out <= 1'b0;
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
    .dda_data_in(dda_fsm0_in),
    .valid_in(dda_fsm0_valid_in),

    .map_data_in(dda_fsm0_map_data_in),
    .map_data_valid_in(dda_fsm0_map_data_valid_in),
    .map_addra_out(dda_fsm0_map_addra_out),
    .map_request_out(dda_fsm0_map_request_out),

    .hcount_ray_out(dda_fsm0_hcount_ray_out),
    .lineHeight_out(dda_fsm0_lineHeight_out),
    .wallType_out(dda_fsm0_wallType_out),
    .mapData_out(dda_fsm0_mapData_out),
    .wallX_out(dda_fsm0_wallX_out),
    
    .dda_busy_out(dda_fsm0_busy),
    .dda_valid_out(dda_fsm0_valid_out)
  );

  // DDA FSM module 1 HERE (duplicate when ready)



  ////############ MAP DATA BRAM REQUESTS ###############

  // signals for map data requests from each submodule
  logic [2:0] dda_fsm0_map_data_in, dda_fsm1_map_data_in; //data output from bram (input to submodules)
  logic dda_fsm0_map_data_valid_in, dda_fsm1_map_data_valid_in; //1 cycle high when bram done fetching (input to submodules)
  logic [$clog2(N*N)-1:0] dda_fsm0_map_addra_out, dda_fsm1_map_addra_out; //dda_fsm map data address (out from submodules)
  logic [$clog2(N*N)-1:0] dda_fsm0_map_request_out, dda_fsm1_map_request_out; // high while dda_fsm requesting map data (out from submodules)
  
  logic last_granted_fsm;

  //general I/O from BRAM
  logic [$clog2(N*N)-1:0] map_addra; //(hcount_in - x_in) + ((vcount_in - y_in) * WIDTH);
  logic [2:0] map_data;

  enum {
    IDLE, GRANT_FSM0, GRANT_FSM1, ASSIGN
  } MAP_ARBITER_STATE;

  // arbiter logic
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      MAP_ARBITER_STATE <= IDLE;
      dda_fsm0_map_data_in <= 0;
      dda_fsm1_map_data_in <= 0;
      dda_fsm0_map_data_valid_in <= 1'b0;
      dda_fsm1_map_data_valid_in <= 1'b0;
      last_granted_fsm <= 1'b0; // Initialize to a default FSM
    end else begin
      case (MAP_ARBITER_STATE)
        IDLE: begin
          dda_fsm0_map_data_valid_in <= 1'b0;
          dda_fsm1_map_data_valid_in <= 1'b0;

          if (dda_fsm0_map_request_out && dda_fsm1_map_request_out) begin
            // alternate granting based on last_granted_fsm
            map_addra <= (last_granted_fsm) ? dda_fsm0_map_addra_out : dda_fsm1_map_addra_out;
            MAP_ARBITER_STATE <= (last_granted_fsm) ? GRANT_FSM0 : GRANT_FSM1;
          end else if (dda_fsm0_map_request_out) begin
            map_addra <= dda_fsm0_map_addra_out;
            MAP_ARBITER_STATE <= GRANT_FSM0;
          end else if (dda_fsm1_map_request) begin
            map_addra <= dda_fsm1_map_addra;
            MAP_ARBITER_STATE <= GRANT_FSM1;
          end
        end
        
        GRANT_FSM0: begin //cycle 1
          MAP_ARBITER_STATE <= ASSIGN;
          last_granted_fsm <= 1'b1;
        end

        GRANT_FSM1: begin //cycle 1
          MAP_ARBITER_STATE <= ASSIGN;
          last_granted_fsm <= 1'b0;
        end

        ASSIGN: begin //cycle 2 (data ready) - connect BRAM data to the appropriate submodule based on arbiter state
          if (last_granted_fsm == 1'b1) begin //GRANT_FSM0
            dda_fsm0_map_data_valid_in <= 1'b1;
            dda_fsm0_map_data_in <= map_data;
          end else begin
            dda_fsm1_map_data_valid_in <= 1'b1;
            dda_fsm1_map_data_in <= map_data;
          end
          MAP_ARBITER_STATE <= IDLE;
        end

      endcase
    end
  end


  //  2D MAP - Xilinx Single Port Read Firdst RAM
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(4),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
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