module btn_control #(
    parameter ROTATION_ANGLE = 16'b0010_1101_0000_0000, // default = 45 degrees
    parameter N = 24
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
    output logic [15:0] planeY,

    input logic [1:0] map_select
    
    );

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

    // logic signed [15:0] posX_pipe_2;
    // logic signed [15:0] posY_pipe_2;
    // logic signed [15:0] dirX_pipe_2;
    // logic signed [15:0] dirY_pipe_2;
    // logic signed [15:0] planeX_pipe_2;
    // logic signed [15:0] planeY_pipe_2;
    
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
    
    logic [31:0] move_counter;

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
            move_counter <= 1'b0;
        end else begin
            if (move_counter == 10_000_000) begin
                move_counter<=0;
                if (deb_out_fwd) begin
                    fwd_pulse <= 1'b1;
                    is_pulse <= 1'b1;
                end else if (deb_out_bwd) begin
                    bwd_pulse <= 1'b1;
                    is_pulse <= 1'b1;
                end else if (deb_out_leftRot) begin
                    leftRot_pulse <= 1'b1;
                    is_pulse <= 1'b1;
                end else if (deb_out_rightRot) begin
                    rightRot_pulse <= 1'b1;
                    is_pulse <= 1'b1;
                end else begin
        
                end
            // posX_pipe_1 <= posX_pipe_0;
            // posY_pipe_1 <= posY_pipe_0;
            // dirX_pipe_1 <= dirX_pipe_0;
            // dirY_pipe_1 <= dirY_pipe_0;
            // planeX_pipe_1 <= planeX_pipe_0;
            // planeY_pipe_1 <= planeY_pipe_0;
            end 
            else begin
                move_counter<=move_counter+1;
                fwd_pulse<= 1'b0;
                bwd_pulse<= 1'b0;
                leftRot_pulse<= 1'b0;
                rightRot_pulse<= 1'b0;
                is_pulse <= 1'b0;
            end
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

    logic ray_grid_req;
    logic [$clog2(N*N)-1:0] ray_map_addra;

    logic ray_grid_valid;
    //logic [1:0] map_select;
    logic [4:0] ray_grid_data;

    movement_control #(ROTATION_ANGLE) move (
        .clk_in(clk_in),
        .rst_in(rst_in),
        .fwd_pulse(fwd_pulse),
        .bwd_pulse(bwd_pulse),
        .leftRot_pulse(leftRot_pulse),
        .rightRot_pulse(rightRot_pulse),
        .is_pulse(is_pulse),
        .posX(posX_pipe_1),
        .posY(posY_pipe_1),
        .dirX(dirX_pipe_1),
        .dirY(dirY_pipe_1),
        .planeX(planeX_pipe_1), 
        .planeY(planeY_pipe_1),
        
        .ray_grid_req(ray_grid_req),
        .ray_map_addra(ray_map_addra),
        .ray_grid_valid(ray_grid_valid),
        .ray_grid_data(ray_grid_data)
        );


     ////######////######////######////######////######////######////######////######////######
    ///                                                                                 ######
    ///                         RAY CALC MAP INSTANCE                                   ######
    ///                                                                                 ######
    ////######////######////######////######////######////######////######////######////######

    //INSERT RAY GRIDMAP HERE


    grid_map grid_arbiter2 (
        .pixel_clk_in(clk_in),
        .rst_in(rst_in),

        .map_select(map_select), // 0, 1, 2, 3 (4 maps)
        .req_in(ray_grid_req),
        .address_in(ray_map_addra),
        .valid_out(ray_grid_valid),

        .grid_data(ray_grid_data)
    );
    
endmodule