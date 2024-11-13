`timescale 1ns / 1ps
`default_nettype none

// CATHY -- NEW
/*
QUESTIONS:
- do I need valid signal for every hcount, vcount pair
- do I need a valid signal for every address_in, pixel_in pair
to make sure I am not writing or reading invalid addresses
- what happens if you index into an address that does not exist in a BRAM?

if last_pixel_in, we know that we've finished writing to the current frame buffer and we can switch states

at some point, the video_sig_gen will stop generating because it's waiting for the frame buffer --> send signal to video_frame
can you tell video sig gen to stop generating the frame when 
*/

module frame_buffer
                    (
                    input wire pixel_clk_in,
                    input wire rst_in,
                    input wire [10:0] hcount_in, // from video_sig_gen
                    input wire [9:0] vcount_in,
                    // input wire valid_video_gen_in,
                    input wire [15:0] address_in, // from transformating / flattening module (not in order and ranges from 0 to 320*180)
                    input wire [15:0] pixel_in,
                    input wire ray_last_pixel_in, // indicates the last computed pixel in the ray sweep
                    input wire video_last_pixel_in, // indicates the last 
                    output wire video_gen_stop_out, // signals to video_sig_gen to stop generating
                    output wire [23:0] rgb_out);

    localparam PIXEL_WIDTH = 16;
    logic state; // state = 0 (write to fb1, read from fb2), state = 1 (read from fb1, write to fb2)
    logic [7:0] pixel_out;    // output 8-bit pixel representation from frame buffer

    assign address1 = (!state) ? address_in : ((hcount_in >> 2)+((vcount_in >> 2) * 320)); // if writing, address = address_in. if reading, video sig indexing
    assign address2 = (state) ? address_in : ((hcount_in >> 2)+((vcount_in >> 2) * 320));

    // FRAME BUFFER 1
    xilinx_single_port_ram_read_first #( // could have width be equal to PIXEL_WIDTH * height
    .RAM_WIDTH(PIXEL_WIDTH),                          // 16 bits wide (16 bit pixel representation)
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
        .regcea(state && !video_gen_stop_out),             // Output register enabled when state == 1
        .douta(pixel_out)           // RAM output data, width determined from RAM_WIDTH
    );

    // FRAME BUFFER 2
    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),                          // 16 bits wide (16 bit pixel representation)
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
        .regcea(!state && !video_gen_stop_out),            // Output register enabled when state == 0
        .douta(pixel_out)           // RAM output data, width determined from RAM_WIDTH
    );

    // PIXEL PALETTE
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

    logic [1:0] ready_to_switch; // if == 2'b11, then we are ready to switch states
    logic switched; // to indicate to combinational logic that we have switched states and ready_to_switch can go back to 2'b00
    /*
    ready_to_switch
    - collects ray_last_pixel_in and video_last_pixel_in signals
    - after ready_to_switch is reset, if it sees both ray_last_pixel_in and video_last_pixel_in signals go high (not necessarily in any order),
        it signals to the sequential state logic that we are ready to switch states (switch the frame buffers)
        because one frame buffer is done loading all of its ray computed pixels, and the other is done displaying it to the screen
    */
    always_comb begin
        if (rst_in || switched) begin
            ready_to_switch = 2'b0;
            video_gen_stop_out = 0;
        end else if (ray_last_pixel_in || video_last_pixel_in) begin
            if (ray_last_pixel_in) begin
                video_gen_stop_out = 0;
                ready_to_switch[0] = 1;
                if (video_last_pixel_in) begin // in case they are both true at the same time
                    ready_to_switch[1] = 1;
                end
            end else if (video_last_pixel_in) begin
                ready_to_switch[1] = 1;
                if (ray_last_pixel_in) begin
                    ready_to_switch[0] = 1;
                end else begin
                    video_gen_stop_out = 1;
                end
            end
        end
    end

    // all state logic done here
    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            rgb_out <= 0;
            pixel_out <= 0;
            switched <= 0;
        end else begin
            if (ready_to_switch == 2'b11) begin // if we are done displaying all of fb1 and writing to fb2
                state <= !state;
                switched <= 1;
            end else begin
                switched <= 0;
            end
        end
    end

endmodule

`default_nettype wire
