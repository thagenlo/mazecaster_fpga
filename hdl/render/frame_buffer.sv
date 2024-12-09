`timescale 1ns / 1ps
`default_nettype none

`ifdef SYNTHESIS
`define FPATH(X) `"X`"
`else /* ! SYNTHESIS */
`define FPATH(X) `"../../data/X`"
`endif  /* ! SYNTHESIS */


module frame_buffer #(
                        parameter [3:0] PIXEL_WIDTH = 8,
                        parameter [10:0] FULL_SCREEN_WIDTH = 1280,
                        parameter [9:0] FULL_SCREEN_HEIGHT = 720,
                        parameter [8:0] SCREEN_WIDTH = 320,
                        parameter [7:0] SCREEN_HEIGHT = 180
                    )
                    (
                    input wire pixel_clk_in,
                    input wire rst_in,
                    input wire [10:0] hcount_in, // from video_sig_gen
                    input wire [9:0] vcount_in,
                    // input ray_valid_in, // DO I NEED TO HAVE A RAY VALID IN SIGNAL?
                    input wire [15:0] ray_address_in, // from transformating / flattening module (not in order and ranges from 0 to 320*180)
                    input wire [7:0] ray_pixel_in,
                    input wire ray_last_pixel_in, // indicates the last computed pixel in the ray sweep
                    input wire video_last_pixel_in, // indicates the last 
                    output logic [1:0] fb_ready_to_switch_out,
                    output logic [23:0] rgb_out);

    logic state; // state = 0 (write to fb1, read from fb2), state = 1 (read from fb1, write to fb2)

    logic good_address;

    logic [15:0] address1, address2;

    // state = 0: writing to FB1, reading from FB2 (pixel_out_2)
    // state = 1: writing to FB2, reading from FB1 (pixel_out_1)
    assign address1 = (!state) ? ray_address_in : (((hcount_in>>2)) + SCREEN_WIDTH*(vcount_in>>2)); // if writing, address = ray_address_in. if reading, video sig indexing
    assign address2 = (state) ? ray_address_in : (((hcount_in>>2)) + SCREEN_WIDTH*(vcount_in>>2));
    assign good_address = (hcount_in < FULL_SCREEN_WIDTH && vcount_in < FULL_SCREEN_HEIGHT); // valid when hcount_in and vcount_in are in active draw

    logic [7:0] pixel_out1, pixel_out2;
    logic switched; // to indicate to combinational logic that we have switched states and fb_ready_to_switch_out can go back to 2'b00
    
    // FRAME BUFFER 1
    xilinx_single_port_ram_read_first #( // could have width be equal to PIXEL_WIDTH * height
    .RAM_WIDTH(PIXEL_WIDTH), 
    .RAM_DEPTH(57600),                      // number of pixels = 320*180 = 57600 (log2(57600) = 15.814)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()                            // name of RAM initialization file = pop_cat.mem
    ) framebuffer_1 (
        .addra(address1),           // address
        .dina(ray_pixel_in),            // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(!state && !fb_ready_to_switch_out[0]),               // Write enabled when state == 0 AND ready_to_switch[0] != 1
        .ena(1),   // RAM Enable = only enabled when we have a valid address (cannot read from invalid address)
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(1),             // Output register enabled when state == 1
        .douta(pixel_out1)           // RAM output data, width determined from RAM_WIDTH
    );

    // FRAME BUFFER 2
    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),
    .RAM_DEPTH(57600),                      // number of pixels = 320*180 = 57600
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()                            // name of RAM initialization file = none
    ) framebuffer_2 (
        .addra(address2),           // address
        .dina(ray_pixel_in),            // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(state && !fb_ready_to_switch_out[0]),                // Write enabled when state == 1 AND ready_to_switch[0] != 1
        .ena(1),   // RAM Enable = only enabled when we have a valid address
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(1),            // Output register enabled when state == 0
        .douta(pixel_out2)           // RAM output data, width determined from RAM_WIDTH
    );

    logic [7:0] palette_addr;
    assign palette_addr = (state) ? pixel_out1 : pixel_out2;
    
    // PALETTE
    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(24),                          // 24 bit rgb representation
    .RAM_DEPTH(256),                        // 2^8 = 256 possible pixels
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   
    .INIT_FILE(`FPATH(pallete.mem))       
    ) palette (
        .addra(palette_addr),
        .dina(),
        .clka(pixel_clk_in),
        .wea(0),     
        .ena(1), 
        .rsta(rst_in),  
        .regcea(1), 
        .douta(rgb_out)
    );

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            state <= 0;
            switched <= 0;
            fb_ready_to_switch_out <= 2'b00;
        end else if (fb_ready_to_switch_out == 2'b11) begin
            state <= !state;
            switched <= 1;
            fb_ready_to_switch_out <= 2'b00;
        end else if (fb_ready_to_switch_out == 2'b00) begin
            switched <= 0;
            if (ray_last_pixel_in) begin
                fb_ready_to_switch_out[0] <= 1;
                if (video_last_pixel_in) begin // in case they are both true at the same time
                    fb_ready_to_switch_out[1] <= 1;
                end
            end else if (video_last_pixel_in) begin
                fb_ready_to_switch_out[1] <= 1;
                if (ray_last_pixel_in) begin
                    fb_ready_to_switch_out[0] <= 1;
                end
            end
        end else if (fb_ready_to_switch_out == 2'b10) begin
            switched <= 0;
            if (ray_last_pixel_in) begin
                fb_ready_to_switch_out[0] <= 1;
            end
        end else if (fb_ready_to_switch_out == 2'b01) begin
            switched <= 0;
            if (video_last_pixel_in) begin
                fb_ready_to_switch_out[1] <= 1;
            end
        end
    end


endmodule

`default_nettype wire

