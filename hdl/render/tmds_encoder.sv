`timescale 1ns / 1ps
`default_nettype none // prevents system from inferring an undeclared logic (good practice)
 
module tmds_encoder(
  input wire clk_in,
  input wire rst_in,
  input wire [7:0] data_in,  // video data (red, green or blue)
  input wire [1:0] control_in, //for blue set to {vs,hs}, else will be 0
  input wire ve_in,  // video data enable, to choose between control or video signal
  output logic [9:0] tmds_out
);
 
  logic [8:0] q_m;
  logic [4:0] tally;
  logic [4:0] num_ones;
  logic [4:0] num_zeroes;
  logic [4:0] ones_minus_zeroes;
 
    tm_choice mtm(
        .data_in(data_in),
        .qm_out(q_m));

    always_comb begin
        if (ve_in) begin
            num_ones = 0;
            for (int i = 0; i < 8; i = i + 1) begin
                num_ones = num_ones + q_m[i];
            end
            num_zeroes = 8 - num_ones;
            ones_minus_zeroes = num_ones - num_zeroes;
        end
    end
 
    //your code here.
    always_ff @(posedge clk_in) begin
        if (rst_in) begin
            tally <= 0;
            tmds_out <= 0;
        end else if (ve_in == 0) begin
            tally <= 0;
            case (control_in)
                2'b00: tmds_out <= 10'b1101010100;
                2'b01: tmds_out <= 10'b0010101011;
                2'b10: tmds_out <= 10'b0101010100;
                2'b11: tmds_out <= 10'b1010101011;
            endcase
        end else begin // when rst_in = 0, and ve_in = 1
            if ((tally == 0) || (num_ones == num_zeroes)) begin
                tmds_out[9] <= ~q_m[8];
                tmds_out[8] <= q_m[8];
                tmds_out[7:0] <= (q_m[8]) ? q_m[7:0] : ~ q_m[7:0];
                if (q_m[8] == 0) begin
                    tally <= tally - (ones_minus_zeroes);
                end else begin
                    tally <= tally + (ones_minus_zeroes);
                end
            end else begin
                if ((~tally[4] && (num_ones > num_zeroes)) || (tally[4] && (num_zeroes > num_ones))) begin // flip bits
                    tmds_out[9] <= 1;
                    tmds_out[8] <= q_m[8];
                    tmds_out[7:0] <= ~q_m[7:0];
                    tally <= tally + 2*q_m[8] - (ones_minus_zeroes);
                end else begin // keep bits
                    tmds_out[9] <= 0;
                    tmds_out[8] <= q_m[8];
                    tmds_out[7:0] <= q_m[7:0];
                    tally <= tally - 2'd2*(!q_m[8]) + (ones_minus_zeroes);
                end
            end
        end
    end
 
endmodule
 
`default_nettype wire