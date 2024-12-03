`timescale 1ns / 1ps
`default_nettype none

// CATHY -- NEW
/*
QUESTIONS:
- do I need valid signal for every hcount, vcount pair
- do I need a valid signal for every ray_address_in, pixel_in pair
to make sure I am not writing or reading invalid addresses
- what happens if you index into an address that does not exist in a BRAM?

if last_pixel_in, we know that we've finished writing to the current frame buffer and we can switch states

at some point, the video_sig_gen will stop generating because it's waiting for the frame buffer --> send signal to video_frame
can you tell video sig gen to stop generating the frame when 
*/

module frame_buffer #(
                        parameter [4:0] PIXEL_WIDTH = 16,
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
                    input wire [15:0] ray_pixel_in,
                    input wire ray_last_pixel_in, // indicates the last computed pixel in the ray sweep
                    input wire video_last_pixel_in, // indicates the last 
                    output logic [1:0] ready_to_switch,
                    output logic [23:0] rgb_out);

    // localparam PIXEL_WIDTH = 16;
    // localparam FULL_SCREEN_WIDTH = 1280;
    // localparam FULL_SCREEN_HEIGHT = 720;
    // localparam SCREEN_WIDTH = 320;
    // localparam SCREEN_HEIGHT = 180;

    logic state; // state = 0 (write to fb1, read from fb2), state = 1 (read from fb1, write to fb2)
    logic [15:0] pixel_out1, pixel_out2;    // output 16-bit pixel representation from frame buffer
    logic [4:0] red1, red2, blue1, blue2; // (color)1 = pixel color from FB1, (color)2 = pixel color from FB2 (had to do separately so that there was no conflict in output wires)
    logic [5:0] green1, green2;
    // logic [15:0] test_pixel_out1, test_pixel_out2;

    logic good_address;

    logic [15:0] address1, address2;

    // state = 0: writing to FB1, reading from FB2 (pixel_out_2)
    // state = 1: writing to FB2, reading from FB1 (pixel_out_1)
    assign address1 = (!state) ? ray_address_in : (((hcount_in>>2)) + SCREEN_WIDTH*(vcount_in>>2)); // if writing, address = ray_address_in. if reading, video sig indexing
    assign address2 = (state) ? ray_address_in : (((hcount_in>>2)) + SCREEN_WIDTH*(vcount_in>>2));
    assign good_address = (hcount_in < FULL_SCREEN_WIDTH && vcount_in < FULL_SCREEN_HEIGHT); // valid when hcount_in and vcount_in are in active draw

    assign red1 = pixel_out1[15:11];
    assign green1 = pixel_out1[10:5];
    assign blue1 = pixel_out1[4:0];

    assign red2 = pixel_out2[15:11];
    assign green2 = pixel_out2[10:5];
    assign blue2 = pixel_out2[4:0];

    always_comb begin
        if (rst_in) begin
            rgb_out = 0;
        end else if (state) begin // display from fb1
            rgb_out = (good_address) ? {{red1,3'b0}, {green1, 2'b0}, {blue1,3'b0}} : 0;
            // test_pixel_out1 = {red1, green1, blue1};
        end else if (!state) begin
            rgb_out = (good_address) ? {{red2,3'b0}, {green2, 2'b0}, {blue2,3'b0}} : 0;
            // test_pixel_out2 = {red2, green2, blue2};
        end
    end

    // logic [1:0] ready_to_switch; // if == 2'b11, then we are ready to switch states
    logic switched; // to indicate to combinational logic that we have switched states and ready_to_switch can go back to 2'b00
    
    // FRAME BUFFER 1
    xilinx_single_port_ram_read_first #( // could have width be equal to PIXEL_WIDTH * height
    .RAM_WIDTH(PIXEL_WIDTH),                          // 16 bits wide (16 bit pixel representation)
    .RAM_DEPTH(57600),                      // number of pixels = 320*180 = 57600 (log2(57600) = 15.814)
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()                            // name of RAM initialization file = pop_cat.mem
    ) framebuffer_1 (
        .addra(address1),           // address
        .dina(ray_pixel_in),            // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(!state && !ready_to_switch[0]),               // Write enabled when state == 0 AND ready_to_switch[0] != 1
        .ena(1),   // RAM Enable = only enabled when we have a valid address (cannot read from invalid address)
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(1),             // Output register enabled when state == 1
        .douta(pixel_out1)           // RAM output data, width determined from RAM_WIDTH
    );

    // FRAME BUFFER 2
    xilinx_single_port_ram_read_first #(
    .RAM_WIDTH(PIXEL_WIDTH),                          // 16 bits wide (16 bit pixel representation)
    .RAM_DEPTH(57600),                      // number of pixels = 320*180 = 57600
    .RAM_PERFORMANCE("HIGH_PERFORMANCE"),   // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    .INIT_FILE()                            // name of RAM initialization file = none
    ) framebuffer_2 (
        .addra(address2),           // address
        .dina(ray_pixel_in),            // RAM input data = pixel_in from DDA_out buffer
        .clka(pixel_clk_in),        // Clock
        .wea(state && !ready_to_switch[0]),                // Write enabled when state == 1 AND ready_to_switch[0] != 1
        .ena(1),   // RAM Enable = only enabled when we have a valid address
        .rsta(rst_in),              // Output reset (does not affect memory contents)
        .regcea(1),            // Output register enabled when state == 0
        .douta(pixel_out2)           // RAM output data, width determined from RAM_WIDTH
    );

    always_ff @(posedge pixel_clk_in) begin
        if (rst_in) begin
            state <= 0;
            switched <= 0;
            ready_to_switch <= 2'b00;
        end else if (ready_to_switch == 2'b11) begin
            state <= !state;
            switched <= 1;
            ready_to_switch <= 2'b00;
        end else if (ready_to_switch == 2'b00) begin
            switched <= 0;
            if (ray_last_pixel_in) begin
                ready_to_switch[0] <= 1;
                if (video_last_pixel_in) begin // in case they are both true at the same time
                    ready_to_switch[1] <= 1;
                end
            end else if (video_last_pixel_in) begin
                ready_to_switch[1] <= 1;
                if (ray_last_pixel_in) begin
                    ready_to_switch[0] <= 1;
                end
            end
        end else if (ready_to_switch == 2'b10) begin
            switched <= 0;
            if (ray_last_pixel_in) begin
                ready_to_switch[0] <= 1;
            end
        end else if (ready_to_switch == 2'b01) begin
            switched <= 0;
            if (video_last_pixel_in) begin
                ready_to_switch[1] <= 1;
            end
        end
    end
    
    // always_ff @(posedge pixel_clk_in) begin
    //     if (rst_in) begin
    //         state <= 0;
    //         switched <= 0;
    //         ready_to_switch <= 2'b00;
    //     end else if (ready_to_switch == 2'b11) begin
    //         state <= !state;
    //         switched <= 1;
    //         ready_to_switch <= 2'b00;
    //     end else begin
    //         switched <= 0;
    //         if (ray_last_pixel_in) begin
    //             ready_to_switch[0] <= 1;
    //             if (video_last_pixel_in) begin // in case they are both true at the same time
    //                 ready_to_switch[1] <= 1;
    //             end
    //         end else if (video_last_pixel_in) begin
    //             ready_to_switch[1] <= 1;
    //             if (ray_last_pixel_in) begin
    //                 ready_to_switch[0] <= 1;
    //             end
    //         end
    //     end
    // end


endmodule

`default_nettype wire

