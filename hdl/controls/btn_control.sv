module btn_control #(
    parameter ROTATION_ANGLE = 16'b0010_1101_0000_0000 // default = 45 degrees
    )(input wire clk_in,
    input wire rst_in,
    input wire fwd_btn, 
    input wire bwd_btn, 
    input wire leftRot_btn, 
    input wire rightRot_btn,
    output logic [15:0] posX, 
    output logic [15:0] posY,
    output logic [15:0] dirX, 
    output logic [15:0] dirY,
    output logic [15:0] planeX, 
    output logic [15:0] planeY);

    // localparam COS_OF_45 = 16'b0000000010110101; //cos(10) = 0.70703125 in FP

    logic deb_out_fwd, deb_out_bwd, deb_out_leftRot, deb_out_rightRot;
    logic past_fwd, past_bwd, past_leftRot, past_rightRot;
    logic fwd_pulse, bwd_pulse, leftRot_pulse, rightRot_pulse;
    
    debouncer deb_fwd_btn (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dirty_in(fwd_btn),
        .clean_out(deb_out_fwd));

    debouncer deb_bwd_btn (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dirty_in(bwd_btn),
        .clean_out(deb_out_bwd));
    
    debouncer deb_leftRot_btn (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dirty_in(leftRot_btn),
        .clean_out(deb_out_leftRot));

    debouncer deb_rightRot_btn (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .dirty_in(rightRot_btn),
        .clean_out(deb_out_rightRot));

    always_ff @(posedge clk_in)begin
    //enabling signal if old input equals new input
        past_fwd <= deb_out_fwd;
        past_bwd <= deb_out_bwd;
        past_leftRot <= deb_out_leftRot;
        past_rightRot <= deb_out_rightRot;
        if (rst_in) begin
            fwd_pulse<= 1'b0;
            bwd_pulse<= 1'b0;
            leftRot_pulse<= 1'b0;
            rightRot_pulse<= 1'b0;
        end else if (~past_fwd && deb_out_fwd) begin
            fwd_pulse <= 1'b1;
        end else if (~past_bwd && deb_out_bwd) begin
            bwd_pulse <= 1'b1;
        end else if (~past_leftRot && deb_out_leftRot) begin
            leftRot_pulse <= 1'b1;
        end else if (~past_rightRot && deb_out_rightRot) begin
            rightRot_pulse <= 1'b1;
        end else begin
            fwd_pulse<= 1'b0;
            bwd_pulse<= 1'b0;
            leftRot_pulse<= 1'b0;
            rightRot_pulse<= 1'b0;
    end

    // logic [3:0] btn_pulses = {fwd_pulse, bwd_pulse, leftRot_pulse, rightRot_pulse};

    // input wire clk_in,
    // input wire rst_in,
    // input wire fwd_pulse, 
    // input wire bwd_pulse, 
    // input wire leftRot_pulse, 
    // input wire rightRot_pulse,
    // output logic [15:0] posX, 
    // output logic [15:0] posY,
    // output logic [15:0] dirX, 
    // output logic [15:0] dirY,
    // output logic [15:0] planeX, 
    // output logic [15:0] planeY
    
    end
    movement_control #(ROTATION_ANGLE) move (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .fwd_pulse(fwd_pulse),
        .bwd_pulse(bwd_pulse),
        .leftRot_pulse(leftRot_pulse),
        .rightRot_pulse(rightRot_pulse),
        .posX(posX),
        .posY(posY),
        .dirX(dirX),
        .dirY(dirY),
        .planeX(planeX), 
        .planeY(planeY));

endmodule