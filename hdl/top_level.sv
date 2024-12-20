`default_nettype none // prevents system from inferring an undeclared logic (good practice)

`define FPATH(X) `"../data/X`" //`"../../data/X`"
 
module top_level(
    input wire clk_100mhz,                  //crystal reference clock
    input wire [3:0] btn,                   // buttons for move control and rotation
    input wire [15:0] sw,                   // switches
    input wire [3:0] pmodb,
    output logic [2:0]  rgb0,               // rgbs : need to drive them even if not using
    output logic [2:0]  rgb1,
    output logic [15:0] led,                //16 green output LEDs (located right above switches)
    output logic [3:0] ss0_an,//anode control for upper four digits of seven-seg display
    output logic [3:0] ss1_an,//anode control for lower four digits of seven-seg display
    output logic [6:0] ss0_c, //cathode controls for the segments of upper four digits
    output logic [6:0] ss1_c, //cathode controls for the segments of lower four digits
    output logic [2:0] hdmi_tx_p,           //hdmi output signals (positives) (blue, green, red)
    output logic [2:0] hdmi_tx_n,           //hdmi output signals (negatives) (blue, green, red)
    output logic hdmi_clk_p, hdmi_clk_n     //differential hdmi clock
    );
    localparam N = 24;

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

    // logic leftRot_btn;
    // logic rightRot_btn;
    // logic fwd_btn;
    // logic bwd_btn;

    // assign leftRot_btn = btn[1];
    // assign rightRot_btn = btn[0];
    // assign fwd_btn = btn[3];
    // assign bwd_btn = btn[2];


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

    //TODO: PIPELINING
    // PIPELINING for video sig gen
    localparam VIDEO_PIPE_STAGES = 4;
    logic [VIDEO_PIPE_STAGES-1:0] vs_out_pipe, hs_out_pipe, ad_out_pipe;

    always_ff @(posedge clk_pixel) begin
        vs_out_pipe[0] <= vert_sync;
        hs_out_pipe[0] <= hor_sync;
        ad_out_pipe[0] <= active_draw;
        for (int i = 1; i < VIDEO_PIPE_STAGES; i=i+1) begin
            vs_out_pipe[i] <= vs_out_pipe[i-1];
            hs_out_pipe[i] <= hs_out_pipe[i-1];
            ad_out_pipe[i] <= ad_out_pipe[i-1];
        end
    end

    //TODO: INSERT CONTROLLER MODULE

    logic [15:0] posX, posY;
    logic [15:0] dirX, dirY;
    logic [15:0] planeX, planeY;
    // logic valid_controller_out;


    //CONTROL BUTTONS
    logic leftRot_btn;
    logic rightRot_btn;
    logic fwd_btn;
    logic bwd_btn;

    // assign leftRot_btn = btn[1];
    // assign rightRot_btn = btn[0];
    // assign fwd_btn = btn[3];
    // assign bwd_btn = btn[2];
    // // logic start_raycaster;

    assign leftRot_btn = pmodb[1];
    assign rightRot_btn = pmodb[0];
    assign fwd_btn = pmodb[3];
    assign bwd_btn = pmodb[2];
    // logic start_raycaster;

    btn_control controller (
        .clk_in(clk_pixel),
        .rst_in(sys_rst),
        .fwd_btn(!fwd_btn),
        .bwd_btn(!bwd_btn),
        .leftRot_btn(!leftRot_btn),
        .rightRot_btn(!rightRot_btn),
        .frame_switch(frame_buff_ready[0]),
        .posX(posX),
        .posY(posY),
        .dirX(dirX),
        .dirY(dirY),
        .planeX(planeX), 
        .planeY(planeY),
        .map_select(map_select)
    );

    logic start_timer;
    logic [5:0] timer_out;
    logic timer_done;

    // TIMER
    // input wire clk_in,
    // input wire rst_in,
    // input wire [3:0] btn,                   // buttons for move control and rotation
    // input wire [15:0] sw, 
    // input wire [15:0] posX, 
    // input wire [15:0] posY,
    // input wire timer_done,
    // output logic [1:0] screen_display,
    // // output logic game_state,
    // output logic start_timer
    timer #(
        .TIMER_SECONDS(60)
    ) game_timer (
        .clk_100mhz_in(clk_pixel),
        .rst_in(sys_rst),
        .start_timer_in(start_timer),
        .time_out(timer_out),
        .timer_done_out(timer_done)
    );

    logic [6:0] ss_c;
    logic [1:0] screen_display;
    assign ss0_c = ss_c; //control upper four digit's cathodes!
    assign ss1_c = ss_c;

    game_fsm game(.clk_in(clk_pixel),
                               .rst_in(sys_rst),
                               .posX(posX),
                               .posY(posY),
                               .btn(btn),
                               .sw(sw),
                               .timer_done(timer_done),
                               .screen_display(screen_display),
                               .start_timer(start_timer));

    assign led[15] = screen_display[1];
    assign led[14] = screen_display[0];
                               

    seven_segment_controller mssc(.clk_in(clk_pixel),
                               .rst_in(sys_rst),
                            //    .val_in({posX,posY}),
                               .val_in(timer_out),
                               .cat_out(ss_c),
                               .an_out({ss0_an, ss1_an}));

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
                if ((hcount_ray_in == 319)) begin
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
        .ray_calc_busy(busy_ray_calc),
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
        .sender_axis_tdata({5'b0_0000, hcount_ray_in, stepX, stepY, rayDirX, rayDirY, deltaDistX, deltaDistY, posX, posY, sideDistX, sideDistY}), // Heba input
        .sender_axis_tlast(),
        .sender_axis_prog_full(),
        // receiver interface (output from FIFO)
        .receiver_axis_tvalid(dda_fsm_in_tvalid), // out - indicates the FIFO has valid data for the receiver to consume
        .receiver_axis_tready(dda_fsm_in_tready), // in - indicates the receiver is ready to consume data
        .receiver_axis_tdata(dda_fsm_in_tdata), //  out - the actual data being received from the FIFO
        .receiver_axis_tlast(), // FIFO
        .receiver_axis_prog_empty());


    ////######////######////######////######////######////######////######////######////######
    ///                                                                                 ######
    ///                         START DDA MAP INSTANCE                                   ######
    ///                                                                                 ######
    ////######////######////######////######////######////######////######////######////######


    localparam MAP_SIZE = N*N;
    localparam MAP_SIZE_2 = 2*MAP_SIZE;
    localparam MAP_SIZE_3 = 3*MAP_SIZE;
    localparam MAP_DATA_WIDTH = 5;

    logic [$clog2(N*N*4)-1:0] address_dda;
    //logic [4:0] dda_map_data1, dda_map_data2, dda_map_data3, dda_map_data4;
    always_comb begin
        case (map_select)
            0: address_dda = map_addra_top_level;
            1: address_dda = map_addra_top_level + MAP_SIZE;
            2: address_dda = map_addra_top_level + MAP_SIZE_2;
            3: address_dda = map_addra_top_level + MAP_SIZE_3;
        endcase
    end

    xilinx_single_port_ram_read_first #(
        .RAM_WIDTH(MAP_DATA_WIDTH),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
        .RAM_DEPTH(4*MAP_SIZE),                     // RAM depth (number of entries) - (24x24 = 576 entries)
        .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
        .INIT_FILE(`FPATH(all_maps.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    ) grid_dda (
        .addra(address_dda),     // Address bus, width determined from RAM_DEPTH
        .dina(0),       // RAM input data, width determined from RAM_WIDTH
        .clka(clk_pixel),       // Clock
        .wea(0),         // Write enable
        .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
        .rsta(sys_rst),       // Output reset (does not affect memory contents)
        .regcea(1),   // Output register enable
        .douta(map_data_top_level)      // RAM output data, width determined from RAM_WIDTH
    );


    //  2D MAP - Xilinx Single Port Read First RAM (from lab06 image_sprite)
    // MAP 1 UNTEXTURED
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(5),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
    //     .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    //     .INIT_FILE(`FPATH(hedge_maze_24x24.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    // ) worldMap1 (
    //     .addra(map_addra_top_level),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(clk_pixel),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(sys_rst),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(map_data1_top_level)      // RAM output data, width determined from RAM_WIDTH
    // );

    // // MAP 2 TEXTURED
    // xilinx_single_port_ram_read_first #(
    //     .RAM_WIDTH(5),                       // RAM data width (Int at map[mapX][mapY] from 0 -> 2^4, 16)
    //     .RAM_DEPTH(N*N),                     // RAM depth (number of entries) - (24x24 = 576 entries)
    //     .RAM_PERFORMANCE("HIGH_PERFORMANCE"), // Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
    //     .INIT_FILE(`FPATH(hedge_maze_24x24.mem))          //TODO name/location of RAM initialization file if using one (leave blank if not)
    // ) worldMap2 (
    //     .addra(map_addra_top_level),     // Address bus, width determined from RAM_DEPTH
    //     .dina(0),       // RAM input data, width determined from RAM_WIDTH
    //     .clka(clk_pixel),       // Clock
    //     .wea(0),         // Write enable
    //     .ena(1),         // RAM Enable, for additional power savings, disable port when not in use
    //     .rsta(sys_rst),       // Output reset (does not affect memory contents)
    //     .regcea(1),   // Output register enable
    //     .douta(map_data2_top_level)      // RAM output data, width determined from RAM_WIDTH
    // );


    ////######////######////######////######////######////######////######////######////######
    ///                                                                                 ######
    ///                          END DDA MAP INSTANCE                                   ######
    ///                                                                                 ######
    ////######////######////######////######////######////######////######////######////######

    logic grid_req;
    logic [$clog2(N*N)-1:0] grid_address;
    logic grid_valid;
    logic [4:0] grid_data;


    grid_map grid_arbiter (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),

        .map_select(map_select), // 0, 1, 2, 3 (4 maps)
        .req_in(grid_req),
        .address_in(grid_address),
        .valid_out(grid_valid),

        .grid_data(grid_data)
    );

    //map BRAM data
    //logic [4:0] map_data1_top_level, map_data2_top_level;
    logic [4:0] map_data_top_level;
    logic [$clog2(N*N)-1:0] map_addra_top_level;


    // dda-out fifo senders
    logic dda_fsm_out_tready, dda_fsm_out_tvalid, dda_fsm_out_tlast;
    logic [38:0] dda_fsm_out_tdata;

    logic [1:0] map_select;
    assign map_select = sw[5:4]; //CHANGE TO MORE OPTIONS

    // DDA MODULE
    dda #(
        .SCREEN_WIDTH(320),
        .SCREEN_HEIGHT(180), 
        .N(24)
    ) dda_module (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),

        //.map_select(map_select),

        //handle maps
        //.map_data1_top_level(map_data1_top_level),
        .map_data_top_level(map_data_top_level),
        .map_addra_top_level(map_addra_top_level),
        
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


    // ILA TESTING MODULE 1
    // testing RAY_CALC -> FIFO_IN -> DDA
    // ila_0 ila_module1(
    //     .clk(clk_pixel),
    //     .probe0(), // input [8:0] hcount_ray_in
    //     .probe1(), // input [7:0] lineHeight_in
    //     .probe2(), // input sender_axis_tvalid
    //     .probe3(), // input sender_axis_tready
    //     .probe4(), // input [8:0] hcount_ray_out
    //     .probe5(), // input [7:0] lineHeight_out
    //     .probe6(), // input receiver_axis_tvalid
    //     .probe7()  // input receiver_axis_tready
    // );



    //TODO: INSERT DDA-out FIFO
    // fifo-out signal to transformer
    logic fifo_tvalid_out;
    logic [39:0] fifo_tdata_out;
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
        .sender_axis_tdata({1'b0, dda_fsm_out_tdata}), // in - actual data being written into the FIFO
        .sender_axis_tlast(dda_fsm_out_tlast), // in - last piece of data in a frame or packet being sent to the FIFO
        .sender_axis_prog_full(),
        .receiver_clk(clk_pixel),
        .receiver_axis_tvalid(fifo_tvalid_out),
        // .receiver_axis_tready(transformer_tready && fb_ready_out),
        .receiver_axis_tready(transformer_tready),
        .receiver_axis_tdata(fifo_tdata_out),
        .receiver_axis_tlast(fifo_tlast_out),
        .receiver_axis_prog_empty()); // unused

    //TODO: INSERT TRANSFORMATION MODULE
    logic [15:0] ray_address_out;
    logic [8:0] ray_pixel_out;
    logic ray_last_pixel_out;
    logic [1:0] frame_buff_ready;
    // logic fb_ready_out;

    transformation_tex flattening_module (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .PosX(posX),
        .PosY(posY),
        .map_select(map_select),
        .grid_valid_in(grid_valid),
        .grid_data(grid_data),
        .grid_req_out(grid_req),
        .grid_address_out(grid_address),
        .dda_fifo_tvalid_in(fifo_tvalid_out),
        .dda_fifo_tdata_in(fifo_tdata_out[38:0]),
        .dda_fifo_tlast_in(fifo_tlast_out),
        .fb_ready_to_switch_in(frame_buff_ready),
        .transformer_tready_out(transformer_tready),
        .ray_address_out(ray_address_out),
        .ray_pixel_out(ray_pixel_out),
        .ray_last_pixel_out(ray_last_pixel_out)
    );
 
    // ILA TESTING MODULE 2

    // testing DDA -> FIFO_out -> transformation
    // ila_0 ila_module2(
    //     .clk(clk_pixel),
    //     .probe0(dda_fsm_out_tdata[37:29]), // input [8:0] hcount_ray_in
    //     .probe1(dda_fsm_out_tdata[28:21]), // input [7:0] lineHeight_in
    //     .probe2(dda_fsm_out_tvalid), // input sender_axis_tvalid
    //     .probe3(dda_fsm_out_tready), // input sender_axis_tready
    //     .probe4(fifo_tdata_out[37:29]), // input [8:0] hcount_ray_out
    //     .probe5(fifo_tdata_out[28:21]), // input [7:0] lineHeight_out
    //     .probe6(fifo_tvalid_out), // input receiver_axis_tvalid
    //     .probe7(transformer_tready)  // input receiver_axis_tready
    // );
    //map type check
    // ila_0 ila_module2(
    //     .clk(clk_pixel),
    //     .probe0(dda_fsm_out_tdata[37:29]), // input [8:0] hcount_ray_in
    //     .probe1(dda_fsm_out_tdata[28:21]), // input [7:0] lineHeight_in
    //     .probe2(dda_fsm_out_tvalid), // input sender_axis_tvalid
    //     .probe3(dda_fsm_out_tready), // input sender_axis_tready
    //     .probe4(fifo_tdata_out[37:29]), // input [8:0] hcount_ray_out
    //     .probe5(fifo_tdata_out[28:21]), // input [7:0] lineHeight_out
    //     .probe6(fifo_tvalid_out), // input receiver_axis_tvalid
    //     .probe7(dda_fsm_out_tdata[20])  // input wallType_in
    // );


    // PIXEL VALUE WRITING
    logic [23:0] rgb_out; // from the frame buffer

    frame_buffer frame_buffer_module(
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        .game_state_in(screen_display),
        .hcount_in(hcount_video),
        .vcount_in(vcount_video),
        .ray_address_in(ray_address_out),
        .ray_pixel_in(ray_pixel_out),
        .ray_last_pixel_in(ray_last_pixel_out),
        .video_last_pixel_in(last_screen_pixel),
        .fb_ready_to_switch_out(frame_buff_ready),
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
      .ve_in(ad_out_pipe[VIDEO_PIPE_STAGES-1]),
      .tmds_out(tmds_10b[2]));

    tmds_encoder tmds_green(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(green_screen),
      .control_in(2'b0),
      .ve_in(ad_out_pipe[VIDEO_PIPE_STAGES-1]),
      .tmds_out(tmds_10b[1]));

    tmds_encoder tmds_blue(
      .clk_in(clk_pixel),
      .rst_in(sys_rst),
      .data_in(blue_screen),
      .control_in({vs_out_pipe[VIDEO_PIPE_STAGES-1], hs_out_pipe[VIDEO_PIPE_STAGES-1]}),
      .ve_in(ad_out_pipe[VIDEO_PIPE_STAGES-1]),
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