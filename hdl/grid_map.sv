`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */
 
 // MAP 1 UNTEXTURED
module grid_map #(
    parameter N = 24
    )(
    input wire pixel_clk_in,
    input wire rst_in,

    input wire [1:0] map_select, // 0, 1, 2, 3 (4 maps)
    input wire dda_req_in,
    input wire trans_req_in,
    input wire [9:0] dda_address_in,
    input wire [9:0] trans_address_in,

    output logic dda_valid_out,
    output logic trans_valid_out,

    output logic [2:0] grid_data
);

    logic [1:0] dda_valid_pipe, trans_valid_pipe;
    logic past_dda_req, past_trans_req;

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            dda_valid_pipe <= 2'b0;
            trans_valid_pipe <= 2'b0;
            past_dda_req <= 1'b0;
            past_trans_req <= 1'b0;
        end else begin
            if (trans_req_in) begin
                trans_valid_pipe[0] <= (1 & !past_trans_req);

            end else if (dda_req_in) begin // dda needs to keep on requesting until trans_req_in is not high
                dda_valid_pipe[0] <= (1 & !past_dda_req);
            end

            past_dda_req <= dda_req_in;
            past_trans_req <= trans_req_in;

            dda_valid_pipe[1] <= dda_valid_pipe[0];
            trans_valid_pipe[1] <= trans_valid_pipe[0];
        end
    end

    assign dda_valid_out = dda_valid_pipe[1];
    assign trans_valid_out = trans_valid_pipe[1];

    logic [15:0] address;
    logic [2:0] map_data1, map_data2, map_data3, map_data4;
    always_comb begin
        if (trans_req_in && dda_req_in) begin
            address = trans_address_in;
        end else if (trans_req_in && !dda_req_in) begin
            address = trans_address_in;
        end else if (!trans_req_in && dda_req_in) begin
            address = dda_address_in;
        end else begin
            address = 0;
        end
        
        case (map_select)
            0: grid_data = map_data1;
            1: grid_data = map_data2;
            2: grid_data = map_data3;
            3: grid_data = map_data4;
        endcase
    end
    
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(3),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
        .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(grid_24x24_onlywall.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    ) grid1 (
        .addra(address),     // Address bus, width determined from RAM_DEPTH
        .dina(0),       // RAM input data, width determined from RAM_WIDTH
        .clka(pixel_clk_in),       // Clock
        .wea(0),         // Write enable
        .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1),   // Output register enable
        .douta(map_data1)      // RAM output data, width determined from RAM_WIDTH
    );

    // MAP 2 TEXTURED: 3 little pigs
    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(3),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
        .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(grid_24x24_onlywall_tex.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    ) grid2 (
        .addra(address),     // Address bus, width determined from RAM_DEPTH
        .dina(0),       // RAM input data, width determined from RAM_WIDTH
        .clka(pixel_clk_in),       // Clock
        .wea(0),         // Write enable
        .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(rst_in),       // Output reset (does not affect memory contents)
        .regcea(1),   // Output register enable
        .douta(map_data2)      // RAM output data, width determined from RAM_WIDTH
    );

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