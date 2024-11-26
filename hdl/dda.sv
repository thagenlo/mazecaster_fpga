//`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */

module dda
#(
  parameter SCREEN_WIDTH = 320,
  parameter SCREEN_HEIGHT = 180,
  parameter N = 24
)
(
  input wire pixel_clk_in,
  input wire rst_in,

  // dda_in FIFO receiver
  input wire dda_fsm_in_tvalid,
  input wire [138:0] dda_fsm_in_tdata, // (hcount_ray, rayDir_in, sideDist_in, deltaDist_in, map_in) - (9 + (4*32)) = 139
  output logic dda_fsm_in_tready,


  // dda_out FIFO sender
  input wire dda_fsm_out_tready,
  output logic [37:0] dda_fsm_out_tdata,
        // [8:0] hcount_ray_out
        // [7:0] lineHeight_out (240/perpWallDist)
        // wallType_out (0 = X wall hit, 1 = Y wall hit)
        // [3:0] mapData_out (value 0 -> 2^4 at map[mapX][mapY] from BROM)
        // [15:0] wallX_out (where on wall the ray hits)
  output logic dda_fsm_out_tvalid, // indicates when to store (x, lineHeight, wallType, mapData) in DDA_fifo_out
  output logic dda_fsm_out_tlast //TODO indicator for the 320th ray
  
  );

  logic dda_fsm0_busy, dda_fsm1_busy, dda_fsm0_valid_out, dda_fsm1_valid_out,
        dda_fsm0_valid_in, dda_fsm1_valid_in;
  logic [138:0] dda_fsm0_in, dda_fsm1_in;
  logic [8:0] dda_fsm0_hcount_ray_out, dda_fsm1_hcount_ray_out;
  logic [7:0] dda_fsm0_lineHeight_out, dda_fsm1_lineHeight_out;
  logic dda_fsm0_wallType_out, dda_fsm1_wallType_out;
  logic [3:0] dda_fsm0_mapData_out, dda_fsm1_mapData_out;
  logic [15:0] dda_fsm0_wallX_out, dda_fsm1_wallX_out;
  logic tLast_out;


  ////############ DDA FIFO ###############
  assign dda_fsm_in_tready = !dda_fsm0_busy || !dda_fsm1_busy; // ready if either FSMs are free
  always_ff @(posedge pixel_clk_in) begin
      if (rst_in) begin
          dda_fsm0_valid_in <= 1'b0;
          dda_fsm1_valid_in <= 1'b0;
          dda_fsm0_in <= 0;
          dda_fsm1_in <= 0;
      end else begin
          // provide data to FSM0 when valid and FSM0 is ready
          if (dda_fsm_in_tvalid && !dda_fsm0_busy) begin
              dda_fsm0_in <= dda_fsm_in_tdata;
              dda_fsm0_valid_in <= 1'b1;
          end else begin
              dda_fsm0_valid_in <= 1'b0;
          end

          // provide data to FSM1 when valid and FSM1 is ready
          if (dda_fsm_in_tvalid && !dda_fsm1_busy && dda_fsm0_busy) begin
              dda_fsm1_in <= dda_fsm_in_tdata;
              dda_fsm1_valid_in <= 1'b1;
          end else begin
              dda_fsm1_valid_in <= 1'b0;
          end
      end
  end

  // output multiplexing based on valid_out signals from DDA FSMs
  always_ff @(posedge pixel_clk_in) begin
    if (rst_in) begin
      dda_fsm_out_tvalid <= 0;
      dda_fsm_out_tlast <= 0;
    end else begin
      if (dda_fsm0_valid_out) begin //single cycle valid out
        dda_fsm_out_tdata <= {dda_fsm0_hcount_ray_out, 
                              dda_fsm0_lineHeight_out, 
                              dda_fsm0_wallType_out, 
                              dda_fsm0_mapData_out, 
                              dda_fsm0_wallX_out};
        dda_fsm_out_tlast <= tLast_out;
        dda_fsm_out_tvalid <= 1'b1;
      end else if (dda_fsm1_valid_out) begin //single cycle valid out
        dda_fsm_out_tdata <= {dda_fsm1_hcount_ray_out, 
                             dda_fsm1_lineHeight_out, 
                             dda_fsm1_wallType_out, 
                             dda_fsm1_mapData_out, 
                             dda_fsm1_wallX_out};
        dda_fsm_out_tlast <= tLast_out;
        dda_fsm_out_tvalid <= 1'b1;
      end else begin
        dda_fsm_out_tlast <= 1'b0;
        dda_fsm_out_tvalid <= 1'b0;
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

    .dda_fsm_out_tready(dda_fsm_out_tready),

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

  // DDA FSM module 1 HERE
  dda_fsm #(
    .SCREEN_WIDTH(SCREEN_WIDTH),
    .SCREEN_HEIGHT(SCREEN_HEIGHT),
    .N(N)
  ) dda_fsm1 (
    .pixel_clk_in(pixel_clk_in),
    .rst_in(rst_in),
    .dda_data_in(dda_fsm1_in),
    .valid_in(dda_fsm1_valid_in),

    .dda_fsm_out_tready(dda_fsm_out_tready),

    .map_data_in(dda_fsm1_map_data_in),
    .map_data_valid_in(dda_fsm1_map_data_valid_in),
    .map_addra_out(dda_fsm1_map_addra_out),
    .map_request_out(dda_fsm1_map_request_out),

    .hcount_ray_out(dda_fsm1_hcount_ray_out),
    .lineHeight_out(dda_fsm1_lineHeight_out),
    .wallType_out(dda_fsm1_wallType_out),
    .mapData_out(dda_fsm1_mapData_out),
    .wallX_out(dda_fsm1_wallX_out),
    
    .dda_busy_out(dda_fsm1_busy),
    .dda_valid_out(dda_fsm1_valid_out)
  );

  ////############ TLAST COUNTER ###############

  // internal signals to detect rising edges
  logic dda_fsm0_valid_out_d; // delayed version of dda_fsm0_valid_out
  logic dda_fsm1_valid_out_d; // delayed version of dda_fsm1_valid_out
  logic dda_fsm0_rising_edge; // rising edge detection for dda_fsm0_valid_out
  logic dda_fsm1_rising_edge; // rising edge detection for dda_fsm1_valid_out

  // detect rising edges
  always_ff @(posedge pixel_clk_in) begin
      if (rst_in) begin
          dda_fsm0_valid_out_d <= 1'b0;
          dda_fsm1_valid_out_d <= 1'b0;
      end else begin
          dda_fsm0_valid_out_d <= dda_fsm0_valid_out;
          dda_fsm1_valid_out_d <= dda_fsm1_valid_out;
      end
  end

  assign dda_fsm0_rising_edge = dda_fsm0_valid_out && !dda_fsm0_valid_out_d; // high only on rising edge
  assign dda_fsm1_rising_edge = dda_fsm1_valid_out && !dda_fsm1_valid_out_d; // high only on rising edge

  // calculate increment (0, 1, or 2)
  logic [1:0] increment;
  assign increment = dda_fsm0_rising_edge + dda_fsm1_rising_edge;

  logic [8:0] ray_counter_out; 
  evt_counter #(
      .MAX_COUNT(SCREEN_WIDTH)
  ) ray_counter (
      .clk_in(pixel_clk_in),
      .rst_in(rst_in),
      .evt_in(increment),
      .count_out(ray_counter_out)
  );

  assign tLast_out = (ray_counter_out == SCREEN_WIDTH-1) || 
                     (ray_counter_out + increment > SCREEN_WIDTH-1 && ray_counter_out <= SCREEN_WIDTH-1);


  ////############ MAP DATA BRAM REQUESTS ###############

  // signals for map data requests from each submodule
  logic [3:0] dda_fsm0_map_data_in, dda_fsm1_map_data_in; //data output from bram (input to submodules)
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
          end else if (dda_fsm1_map_request_out) begin
            map_addra <= dda_fsm1_map_addra_out;
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


  //  2D MAP - Xilinx Single Port Read First RAM (from lab06 image_sprite)
  xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(4),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
    .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(grid_24x24_onlywall.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
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