`default_nettype none
module evt_counter
  #(
    parameter MAX_COUNT = 320
  )
  ( input wire          clk_in,
    input wire          rst_in,
    input wire [1:0]    evt_in,     // multi-bit input to support increments >1
    output logic[31:0]  count_out
  );

  initial begin
    count_out = 32'b0;
  end

  always_ff @(posedge clk_in) begin
    if (rst_in) begin
      count_out <= 32'b0;
    end else if(evt_in > 0) begin
      if (count_out + evt_in >= MAX_COUNT) begin
        count_out <= (count_out + evt_in) - MAX_COUNT;
      end else begin
        count_out <= count_out + evt_in;
      end
    end
  end

endmodule
`default_nettype wire