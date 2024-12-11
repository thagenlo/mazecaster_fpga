`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */
 
 // MAP 1 UNTEXTURED
module grid_map #(
    parameter N = 24,
    parameter MAP_DATA_WIDTH = 5
    )(
    input wire pixel_clk_in,
    input wire rst_in,

    input wire [2:0] map_select, // 0, 1, 2, 3 (4 maps)
    // input wire dda_req_in,
    input wire req_in,
    // input wire [9:0] dda_address_in,
    input wire [$clog2(N*N)-1:0] address_in,

    // output logic dda_valid_out,
    output logic valid_out,

    output logic [4:0] grid_data
);

    logic [1:0] valid_pipe;
    // logic [1:0] dda_valid_pipe, valid_pipe;
    logic past_dda_req, past_req;

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            valid_pipe <= 2'b0;
            past_req <= 1'b0;
        end else begin
            if (req_in) begin
                valid_pipe[0] <= (1 & !past_req);
            end
            past_req <= req_in;

            valid_pipe[1] <= valid_pipe[0];
        end
    end
    assign valid_out = valid_pipe[1];

    logic [$clog2(N*N*4)-1:0] address;
    logic [4:0] map_data1, map_data2, map_data3, map_data4;
    always_comb begin
        case (map_select)
            0: address = address_in;
            1: address = address_in + MAP_SIZE;
            2: address = address_in + MAP_SIZE_2;
            3: address = address_in + MAP_SIZE_3;
        endcase
    end

    localparam MAP_SIZE = N*N;
    localparam MAP_SIZE_2 = 2*MAP_SIZE;
    localparam MAP_SIZE_3 = 3*MAP_SIZE;

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(MAP_DATA_WIDTH),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
        .RAM_DEPTH(4*MAP_SIZE),                     // RAM depth (number of entries) - (24x24 = 576 entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(all_maps.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    ) grid1 (
        .addra(address),     // Address bus, width determined from RAM_DEPTH
        .dina(0),       // RAM input data, width determined from RAM_WIDTH
        .clka(pixel_clk_in),       // Clock
        .wea(0),         // Write enable
        .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1),   // Output register enable
        .douta(grid_data)      // RAM output data, width determined from RAM_WIDTH
    );
    
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(MAP_DATA_WIDTH),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
    //     .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    //     .INIT_FILE(`FPATH(hedge_maze_24x24.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    // ) grid1 (
    //     .addra(address),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(pixel_clk_in),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(rst_in),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(map_data1)      // RAM output data, width determined from RAM_WIDTH
    // );

    // // MAP 2 TEXTURED: 3 little pigs
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(MAP_DATA_WIDTH),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
    //     .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    //     .INIT_FILE(`FPATH(hedge_maze_24x24.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    // ) grid2 (
    //     .addra(address),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(pixel_clk_in),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(rst_in),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(map_data2)      // RAM output data, width determined from RAM_WIDTH
    // );

    // // MAP 3 TEXTURED: mushrooms and frogs and trees + green grass
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(4),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
    //     .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    //     .INIT_FILE(`FPATH(grid_24x24_onlywall_tex.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    // ) worldMap3 (
    //     .addra(address),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(pixel_clk_in),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(rst_in),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(map_data3)      // RAM output data, width determined from RAM_WIDTH
    // );

endmodule