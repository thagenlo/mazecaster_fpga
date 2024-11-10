`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module top_level(
    input wire clk_100mhz, //crystal reference clock
    input wire btn,         // reset button
    output logic [2:0] hdmi_tx_p, //hdmi output signals (positives) (blue, green, red)
    output logic [2:0] hdmi_tx_n, //hdmi output signals (negatives) (blue, green, red)
    output logic hdmi_clk_p, hdmi_clk_n //differential hdmi clock
    );

    // RESET SIGNAL
    logic sys_rst;
    assign sys_rst = btn;

    // CLOCK
    logic clk_pixel, clk_5x; //clock lines
    logic locked; //locked signal (we'll leave unused but still hook it up)

    //clock manager...creates 74.25 Hz and 5 times 74.25 MHz for pixel and TMDS
    hdmi_clk_wiz_720p mhdmicw (
        .reset(0),
        .locked(locked),
        .clk_ref(clk_100mhz),
        .clk_pixel(clk_pixel),
        .clk_tmds(clk_5x));

    // VIDEO SIGNAL GENERATION
    logic [10:0] hcount_video; //hcount of system!
    logic [9:0] vcount_video; //vcount of system!
    logic hor_sync; //horizontal sync signal
    logic vert_sync; //vertical sync signal
    logic active_draw; //ative draw! 1 when in drawing region.0 in blanking/sync
    logic new_frame; //one cycle active indicator of new frame of info!
    logic last_screen_pixel;
    logic [5:0] frame_count; //0 to 59 then rollover frame counter

    video_sig_gen mvg(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_out(hcount_video),
        .vcount_out(vcount_video),
        .vs_out(vert_sync),
        .hs_out(hor_sync),
        .ad_out(active_draw),
        .nf_out(new_frame),
        .very_last_pixel_out(last_screen_pixel),
        .fc_out(frame_count));

    // RAY CASTING OUTPUTS
    logic address_out;          // address from transformation module
    logic [15:0] ray_pixel_out;     // calculated pixel value from transformation module in 565 format
    logic ray_last_pixel_in;    // signal from transformation module indicating the last calculated pixel from the ray cast
    logic valid_out;            // valid signal telling video sig gen that 

    //TODO: insert all ray modules + transformation module

    // PIXEL VALUE WRITING
    logic [23:0] rgb_out; // from the frame buffer

    frame_buffer frame_buffer_module(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_in(hcount_video),
        .vcount_in(vcount_video),
        .address_in(address_out),
        .pixel_in(ray_pixel_out),
        .ray_last_pixel_in(ray_last_pixel_in),
        .video_last_pixel_in(last_screen_pixel),
        .rgb_out(rgb_out)
    )

    // PIXEL VALUE DISPLAY ON SCREEN
    logic [7:0] red_screen, green_screen, blue_screen; //red green and blue pixel values for output
    assign red_screen = rgb_out[23:16];
    assign green_screen = rgb_out[15:8];  
    assign blue_screen = rgb_out[7:0];

    logic [9:0] tmds_10b [0:2]; //output of each TMDS encoder! (an array of 3 elements that are 10 bits each)
    logic tmds_signal [2:0]; //output of each TMDS serializer!

    // three tmds_encoders (blue, green, red)
    tmds_encoder tmds_red(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(red_screen),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[2]));

    tmds_encoder tmds_green(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(green_screen),
      .control_in(2'b0),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[1]));

    tmds_encoder tmds_blue(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(blue_screen),
      .control_in({vert_sync, hor_sync}),
      .ve_in(active_draw),
      .tmds_out(tmds_10b[0]));

    // three tmds_serializers (blue, green, red):
    tmds_serializer red_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[2]),
        .tmds_out(tmds_signal[2]));

    tmds_serializer green_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[1]),
        .tmds_out(tmds_signal[1]));

    tmds_serializer blue_ser(
        .clk_pixel_in(clk_pixel),
        .clk_5x_in(clk_5x),
        .rst_in(sys_rst),
        .tmds_in(tmds_10b[0]),
        .tmds_out(tmds_signal[0]));

    OBUFDS OBUFDS_blue (.I(tmds_signal[0]), .O(hdmi_tx_p[0]), .OB(hdmi_tx_n[0]));
    OBUFDS OBUFDS_green(.I(tmds_signal[1]), .O(hdmi_tx_p[1]), .OB(hdmi_tx_n[1]));
    OBUFDS OBUFDS_red  (.I(tmds_signal[2]), .O(hdmi_tx_p[2]), .OB(hdmi_tx_n[2]));
    OBUFDS OBUFDS_clock(.I(clk_pixel), .O(hdmi_clk_p), .OB(hdmi_clk_n));

endmodule
`default_nettype wire