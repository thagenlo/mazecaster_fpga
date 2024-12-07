module btn_control #(
    parameter ROTATION_ANGLE = 16'b0010_1101_0000_0000 // default = 45 degrees
    )(input wire clk_in,
    input wire rst_in,
    input wire fwd_btn, 
    input wire bwd_btn, 
    input wire leftRot_btn, 
    input wire rightRot_btn,
    input wire frame_switch,
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
    logic is_pulse;

    logic signed [15:0] posX_pipe_0;
    logic signed [15:0] posY_pipe_0;
    logic signed [15:0] dirX_pipe_0;
    logic signed [15:0] dirY_pipe_0;
    logic signed [15:0] planeX_pipe_0;
    logic signed [15:0] planeY_pipe_0;

    logic signed [15:0] posX_pipe_1;
    logic signed [15:0] posY_pipe_1;
    logic signed [15:0] dirX_pipe_1;
    logic signed [15:0] dirY_pipe_1;
    logic signed [15:0] planeX_pipe_1;
    logic signed [15:0] planeY_pipe_1;
    
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
        past_fwd <= deb_out_fwd;
        past_bwd <= deb_out_bwd;
        past_leftRot <= deb_out_leftRot;
        past_rightRot <= deb_out_rightRot;
        if (rst_in) begin
            fwd_pulse<= 1'b0;
            bwd_pulse<= 1'b0;
            leftRot_pulse<= 1'b0;
            rightRot_pulse<= 1'b0;
            is_pulse <= 1'b0;
        end else begin
            if (~past_fwd && deb_out_fwd) begin
                fwd_pulse <= 1'b1;
                is_pulse <= 1'b1;
            end else if (~past_bwd && deb_out_bwd) begin
                bwd_pulse <= 1'b1;
                is_pulse <= 1'b1;
            end else if (~past_leftRot && deb_out_leftRot) begin
                leftRot_pulse <= 1'b1;
                is_pulse <= 1'b1;
            end else if (~past_rightRot && deb_out_rightRot) begin
                rightRot_pulse <= 1'b1;
                is_pulse <= 1'b1;
            end
            posX_pipe_1 <= posX_pipe_0;
            posY_pipe_1 <= posY_pipe_0;
            dirX_pipe_1 <= dirX_pipe_0;
            dirY_pipe_1 <= dirY_pipe_0;
            planeX_pipe_1 <= planeX_pipe_0;
            planeY_pipe_1 <= planeY_pipe_0;
            if (frame_switch) begin
                posX <= posX_pipe_1;
                posY <= posY_pipe_1;
                dirX <= dirX_pipe_1;
                dirY <= dirY_pipe_1;
                planeX <= planeX_pipe_1;
                planeY <= planeY_pipe_1;
                // start_raycaster <= 1; 
            end
        end
    end

    movement_control #(ROTATION_ANGLE) move (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .fwd_pulse(fwd_pulse),
        .bwd_pulse(bwd_pulse),
        .leftRot_pulse(leftRot_pulse),
        .rightRot_pulse(rightRot_pulse),
        .is_pulse(is_pulse),
        .posX(posX_pipe_0),
        .posY(posY_pipe_0),
        .dirX(dirX_pipe_0),
        .dirY(dirY_pipe_0),
        .planeX(planeX_pipe_0), 
        .planeY(planeY_pipe_0));
    
endmodule