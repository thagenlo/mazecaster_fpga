`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module top_level_dda_test(
    input wire clk_100mhz,                  //crystal reference clock
    input wire [3:0] btn,                   // buttons for move control and rotation
    input wire [15:0] sw,                   // switches
    input wire [138:0] dda_fsm_in_tdata
    );

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

    // Signals for DDA-in FIFO
    logic dda_data_valid_in;
    logic dda_data_ready_out;
    logic [138:0] dda_data_in;

    //DDA-in FIFO
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
        .receiver_axis_tvalid(dda_fsm_in_tvalid), // out - indicates the FIFO has valid data for the receiver to consume
        .receiver_axis_tready(dda_fsm_in_tready), // in - indicates the receiver is ready to consume data
        .receiver_axis_tdata(dda_fsm_in_tdata), //  out - the actual data being received from the FIFO
        .receiver_axis_tlast(), // FIFO
        .receiver_axis_prog_empty());

    //DDA MODULE

    dda #(
        .SCREEN_WIDTH(320),
        .SCREEN_HEIGHT(240), 
        .N(24)
    ) dda_module (
        .pixel_clk_in(clk_pixel),
        .rst_in(sys_rst),
        
        // DDA-in FIFO receiver
        .dda_fsm_in_tvalid(dda_fsm_in_tvalid),
        .dda_fsm_in_tdata(dda_fsm_in_tdata),
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
        .receiver_axis_prog_empty()); // unused


endmodule
`default_nettype wire