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

    //TODO: PIPELINING

    // VIDEO SIGN GEN
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

    //TODO: INSERT CONTROLLER MODULE


    //TODO: INSERT RAY CALCULATION MODULE


    //TODO: INSERT DDA-in FIFO
    ddr_fifo_wrap dda_fifo_in ( // read data output from traffic
        // reset and clock signals
        .sender_rst(sys_rst),
        .sender_clk(clk_pixel),
        .receiver_clk(clk_pixel),
        // sender interface (input to FIFO)
        .sender_axis_tvalid(dda_data_valid_in), // Heba input
        .sender_axis_tready(dda_data_ready_out), // FIFO
        .sender_axis_tdata(dda_data_in), // Heba input
        .sender_axis_tlast(),
        .sender_axis_prog_full(),
        // receiver interface (output from FIFO)
        .receiver_axis_tvalid(dda_fsm_in_tvalid), // indicates the FIFO has valid data for the receiver to consume
        .receiver_axis_tready(dda_fsm_in_tready), // indicates the receiver is ready to consume data
        .receiver_axis_tdata(dda_fsm_in_tdata), //  the actual data being received from the FIFO
        .receiver_axis_tlast(), // FIFO
        .receiver_axis_prog_empty());

    //TODO: INSERT DDA MODULES


    //TODO: INSERT DDA-out FIFO
    // fifo-out signal to transformer
    logic fifo_tvalid_out;
    logic [38:0] fifo_tdata_out;
    logic fifo_tlast_out;
    logic fifo_prog_empty;
    // transformer signal to fifo-out
    logic transformer_tready;

    ddr_fifo_wrap dda_fifo_out ( // read data output from traffic
        .sender_rst(sys_rst),
        .sender_clk(clk_pixel),
        .sender_axis_tvalid(dda_fsm_out_tvalid), // in - data on the sender_axis_tdata signal is valid and can be written into the FIFO
        .sender_axis_tready(dda_fsm_out_tready), // out - FIFO is ready to accept data from the sender
        .sender_axis_tdata(dda_fsm_out_tdata), // in - actual data being written into the FIFO
        .sender_axis_tlast(dda_fsm_out_tlast), // in - last piece of data in a frame or packet being sent to the FIFO
        .sender_axis_prog_full(), //TODO: to here ???
        .receiver_clk(clk_pixel), //TODO: Replace names starting from here
        .receiver_axis_tvalid(fifo_tvalid_out),
        .receiver_axis_tready(transformer_tready),
        .receiver_axis_tdata(fifo_tdata_out),
        .receiver_axis_tlast(fifo_tlast_out),
        .receiver_axis_prog_empty(fifo_prog_empty)); // unused

    //TODO: INSERT TRANSFORMATION MODULE
    logic [15:0] ray_address_out;
    logic [15:0] ray_pixel_out;
    logic ray_last_pixel_out;

    transformation flattening_module (
        .pixel_clk_in(pixel_clk_in),
        .rst_in(sys_rst),
        .dda_fifo_tvalid_in(fifo_tvalid_out),
        .dda_fifo_tdata_in(fifo_tdata_out),
        .dda_fifo_tlast_in(fifo_tlast_out),
        .transformer_tready_out(transformer_tready),
        .ray_address_out(ray_address_out).
        .ray_pixel_out(ray_pixel_out),
        .ray_last_pixel_out(ray_last_pixel_out)
    )

    // PIXEL VALUE WRITING
    logic [23:0] rgb_out; // from the frame buffer

    frame_buffer frame_buffer_module(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_in(hcount_video),
        .vcount_in(vcount_video),
        .address_in(ray_address_out),
        .pixel_in(ray_pixel_out),
        .ray_last_pixel_in(ray_last_pixel_out),
        .video_last_pixel_in(last_screen_pixel),
        .rgb_out(rgb_out) // should I create a valid signal so that 
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