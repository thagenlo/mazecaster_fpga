`timescale 1ns / 1ps
`default_nettype none

// CATHY -- NEW

module frame_buffer
                    (
                    input wire pixel_clk_in,
                    input wire rst_in,
                    input wire [10:0] hcount_in, // from video_sig_gen
                    input wire [9:0] vcount_in,
                    input wire ad_in,
                    input wire [15:0] address_in, // from DDA_out flattening buffer (not in order and ranges from 0 to 320*180)
                    input wire [7:0] pixel_in,
                    output wire valid_out,
                    output wire [10:0] hcount_out,
                    output wire [9:0] vcount_out,
                    output wire [23:0] rgb_out);
    
    logic state; // state = 0 (write to frame buff 1, read from frame buff 2), state = 1 (read from fb1, write to fb2)
    logic [7:0] pixel_out;    // output 8-bit pixel representation from frame buffer

    assign address1 = (!state) ? address_in : ((hcount_in >> 2)+((vcount_in >> 2) * 320)); // if writing, address = address_in. if reading, video sig indexing
    assign address2 = (state) ? address_in : ((hcount_in >> 2)+((vcount_in >> 2) * 320));

    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                          // 8 bits wide (8 bit pixel representation)
    .RAM_DEPTH(57600),                      // number of pixels = 320*180 = 57600 (log2(57600) = 15.814)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()                            // name of RAM initialization file = pop_cat.mem
    ) framebuffer_1 (
        .addra(address1),           // address
        .dina(pixel_in),            // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(!state),               // Write enabled when state == 0
        .ena(1),                    // RAM Enable = always enabled
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(state),             // Output register enabled when state == 1
        .douta(pixel_out)           // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(8),                          // 8 bits wide (8 bit pixel representation)
    .RAM_DEPTH(57600),                      // number of pixels = 320*180 = 57600
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()                            // name of RAM initialization file = none
    ) framebuffer_2 (
        .addra(address2),           // address
        .dina(pixel_in),            // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(state),                // Write enabled when state == 1
        .ena(1),                    // RAM Enable = always enabled
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(!state),            // Output register enabled when state == 0
        .douta(pixel_out)           // RAM output data, width determined from RAM_WIDTH
    );

    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                             // 24 bits wide (565 rgb representation)
    .RAM_DEPTH(256),                            // 2^8 = 256 different pixel represenations 
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),       // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE(`FPATH(palette.mem))                                // name of RAM initialization file = palette.mem
    ) palette (
        .addra(pixel_out),          // address
        .dina(),                    // RAM input data = none since using as ROM
        .clka(pixel_clk_in),        // Clock
        .wea(0),                    // never write to it
        .ena(1),                    // RAM Enable = always enabled
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(1),                 // Output register always enabled
        .douta(rgb_out)           // RAM output data, width determined from RAM_WIDTH
    );

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            rgb_out <= 0;
            pixel_out <= 0;
        end else begin
            if (hcount_in == ) begin
                state <= !state;
            end
        end
    end

endmodule

`default_nettype wire
