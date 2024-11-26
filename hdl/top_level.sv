`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module top_level(
    input wire clk_100mhz,                  //crystal reference clock
    input wire [3:0] btn,                   // buttons for move control and rotation
    input wire [15:0] sw,                   // switches
    output logic [2:0]  rgb0,               // rgbs : need to drive them even if not using
    output logic [2:0]  rgb1,
    output logic [15:0] led,                //16 green output LEDs (located right above switches)
    output logic [2:0] hdmi_tx_p,           //hdmi output signals (positives) (blue, green, red)
    output logic [2:0] hdmi_tx_n,           //hdmi output signals (negatives) (blue, green, red)
    output logic hdmi_clk_p, hdmi_clk_n     //differential hdmi clock
    );

    // shut up those RGBs
    assign rgb0 = 0;
    assign rgb1 = 0;

    // RESET SIGNAL
    logic sys_rst;
    assign sys_rst = sw[0];

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

    //CONTROL BUTTONS

    //debouncing buttons

    logic leftRot_btn;
    logic rightRot_btn;
    logic fwd_btn;
    logic bwd_btn;

    // assign leftRot_btn = btn[1];
    // assign rightRot_btn = btn[0];
    // assign fwd_btn = btn[3];
    // assign bwd_btn = btn[2];
 
    debouncer deb_leftRot_btn (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .dirty_in(btn[1]),
        .clean_out(leftRot_btn));

    debouncer deb_rightRot_btn (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .dirty_in(btn[0]),
        .clean_out(rightRot_btn));
    
    debouncer deb_fwd_btn (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .dirty_in(btn[3]),
        .clean_out(fwd_btn));

    debouncer deb_bwd_btn (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .dirty_in(btn[2]),
        .clean_out(bwd_btn));

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

    logic [15:0] posX, posY;
    logic [15:0] dirX, dirY;
    logic [15:0] planeX, planeY;
    logic valid_controller_out;

    controller controller_in (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .moveFwd(fwd_btn),
        .moveBack(bwd_btn),
        .rotLeft(leftRot_btn),
        .rotRight(rightRot_btn),
        .valid_in(),
        .posX(posX),
        .posY(posY),
        .dirX(dirX),
        .dirY(dirY),
        .planeX(planeX), 
        .planeY(planeY),
        .valid_out(valid_controller_out)
    );

    //TODO: INSERT RAY CALCULATION MODULE

    //TODO: sending in 320 hcounts

    logic [8:0] hcount_ray_in;
    logic [8:0] hcount_ray_out;
    logic stepX;
    logic stepY;
    logic signed [15:0] rayDirX;
    logic signed [15:0] rayDirY;
    logic [15:0] sideDistX;
    logic [15:0] sideDistY;
    logic [15:0] deltaDistX;
    logic [15:0] deltaDistY;

    //generate all hcounts
    always_ff @(posedge clk_pixel) begin
        if (sys_rst) begin
            hcount_ray_in <= 0;
        end else begin
            if (valid_ray_out && dda_data_ready_out) begin
                if (hcount_ray_in == 320) begin
                    hcount_ray_in <= 0;
                end else begin 
                    hcount_ray_in <= hcount_ray_in + 1;
                end
            end
        end
    end


    logic dda_data_valid_in, dda_data_ready_out;
    logic valid_ray_out;
    logic busy_ray_calc;


    ray_calculations calculating_ray (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_in(hcount_ray_in),
        .posX(posX),
        .posY(posY),
        .dirX(dirX),
        .dirY(dirY),
        .planeX(planeX), 
        .planeY(planeY),
        .stepX(stepX),
        .stepY(stepY),
        .rayDirX(rayDirX),
        .rayDirY(rayDirY),
        .sideDistX(sideDistX),
        .sideDistY(sideDistY),
        .deltaDistX(deltaDistX),
        .deltaDistY(deltaDistY),
        // .hcount_out(hcount_ray),
        .dda_data_ready_out(dda_data_ready_out),
        .hcount_out(hcount_ray_out),
        .busy_ray_calc(busy_ray_calc),
        .valid_ray_out(valid_ray_out)
    );

    //TODO: INSERT DDA-in FIFO
    logic dda_fsm_in_tvalid, dda_fsm_in_tready;
    logic [143:0] dda_fsm_in_tdata;//[138:0] dda_fsm_in_tdata;

    dda_fifo_wrap #(
        .DEPTH(256), //2^8 = 256 - ~320
        .DATA_WIDTH(144), // 139 bits (8*18 = 144)
        .PROGFULL_DEPTH(12)
    )dda_fifo_in ( // read data output from traffic
        // reset and clock signals
        .sender_rst(sys_rst),
        .sender_clk(clk_pixel),
        .receiver_clk(clk_pixel),
        // sender interface (input to FIFO)
        .sender_axis_tvalid(valid_ray_out), // Heba input
        .sender_axis_tready(dda_data_ready_out), // FIFO
        .sender_axis_tdata({5'b0_0000, hcount_ray_out, stepX, stepY, rayDirX, rayDirY, deltaDistX, deltaDistY, posX, posY, sideDistX, sideDistY}), // Heba input
        .sender_axis_tlast(),
        .sender_axis_prog_full(),
        // receiver interface (output from FIFO)
        .receiver_axis_tvalid(dda_fsm_in_tvalid), // out - indicates the FIFO has valid data for the receiver to consume
        .receiver_axis_tready(dda_fsm_in_tready), // in - indicates the receiver is ready to consume data
        .receiver_axis_tdata(dda_fsm_in_tdata), //  out - the actual data being received from the FIFO
        .receiver_axis_tlast(), // FIFO
        .receiver_axis_prog_empty());

    // dda-out fifo senders
    logic dda_fsm_out_tready, dda_fsm_out_tvalid, dda_fsm_out_tlast;
    logic [37:0] dda_fsm_out_tdata;

    // DDA MODULE
    dda #(
        .SCREEN_WIDTH(320),
        .SCREEN_HEIGHT(240), 
        .N(24)
    ) dda_module (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        
        // DDA-in FIFO receiver
        .dda_fsm_in_tvalid(dda_fsm_in_tvalid),
        .dda_fsm_in_tdata(dda_fsm_in_tdata[138:0]),
        .dda_fsm_in_tready(dda_fsm_in_tready),
        
        // DDA-out FIFO sender
        .dda_fsm_out_tready(dda_fsm_out_tready),
        .dda_fsm_out_tdata(dda_fsm_out_tdata),
        .dda_fsm_out_tvalid(dda_fsm_out_tvalid),
        .dda_fsm_out_tlast(dda_fsm_out_tlast)
    );

    //TODO: INSERT DDA-out FIFO
    // fifo-out signal to transformer
    logic fifo_tvalid_out;
    logic [37:0] fifo_tdata_out;
    logic fifo_tlast_out;
    logic fifo_prog_empty;
    // transformer signal to fifo-out
    logic transformer_tready;

    dda_fifo_wrap #(
        .DEPTH(256), //2^8 = 256 - ~320
        .DATA_WIDTH(40), // *multiple of 8 9 (hcount) + 8 (line height) + 1 (wall type) + 4 (map data) + 16 (wallX) = 38 bits = [37:0]
        .PROGFULL_DEPTH(12)
    ) dda_fifo_out ( // read data output from traffic
        .sender_rst(sys_rst),
        .sender_clk(clk_pixel),
        .sender_axis_tvalid(dda_fsm_out_tvalid), // in - data on the sender_axis_tdata signal is valid and can be written into the FIFO
        .sender_axis_tready(dda_fsm_out_tready), // out - FIFO is ready to accept data from the sender
        .sender_axis_tdata({2'b00, dda_fsm_out_tdata}), // in - actual data being written into the FIFO
        .sender_axis_tlast(dda_fsm_out_tlast), // in - last piece of data in a frame or packet being sent to the FIFO
        .sender_axis_prog_full(),
        .receiver_clk(clk_pixel),
        .receiver_axis_tvalid(fifo_tvalid_out),
        .receiver_axis_tready(transformer_tready),
        .receiver_axis_tdata(fifo_tdata_out),
        .receiver_axis_tlast(fifo_tlast_out),
        .receiver_axis_prog_empty()); // unused

    //TODO: INSERT TRANSFORMATION MODULE
    logic [15:0] ray_address_out;
    logic [15:0] ray_pixel_out;
    logic ray_last_pixel_out;

    transformation flattening_module (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .dda_fifo_tvalid_in(fifo_tvalid_out),
        .dda_fifo_tdata_in(fifo_tdata_out[37:0]),
        .dda_fifo_tlast_in(fifo_tlast_out),
        .transformer_tready_out(transformer_tready),
        .ray_address_out(ray_address_out),
        .ray_pixel_out(ray_pixel_out),
        .ray_last_pixel_out(ray_last_pixel_out)
    );

    // PIXEL VALUE WRITING
    logic [23:0] rgb_out; // from the frame buffer

    frame_buffer frame_buffer_module(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .hcount_in(hcount_video),
        .vcount_in(vcount_video),
        .ray_address_in(ray_address_out),
        .ray_pixel_in(ray_pixel_out),
        .ray_last_pixel_in(ray_last_pixel_out),
        .video_last_pixel_in(last_screen_pixel),
        .rgb_out(rgb_out) // should I create a valid signal so that 
    );

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