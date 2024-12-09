`default_nettype none
module seven_segment_controller #(parameter COUNT_PERIOD = 100000)
  (input wire           clk_in,
   input wire           rst_in,
   input wire [31:0]    val_in,
   output logic[6:0]    cat_out,
   output logic[7:0]    an_out
  );
 
  logic [7:0]   segment_state;
  logic [31:0]  segment_counter;
  logic [3:0]   sel_values;
  logic [6:0]   led_out;
 
  //TODO: wire up sel_values (-> x_in) with your input, val_in
  //Note that x_in is a 4 bit input, and val_in is 32 bits wide
  //Adjust accordingly, based on what you know re. which digits
  //are displayed when...

  bto7s mbto7s (.x_in(sel_values), .s_out(led_out));
  assign cat_out = ~led_out; //<--note this inversion is needed
  assign an_out = ~segment_state; //note this inversion is needed
 
  always_ff @(posedge clk_in)begin
    if (rst_in)begin
      segment_state <= 8'b0000_0001;
      segment_counter <= 32'b0;
      sel_values<= val_in[3:0];
    end else begin
      if (segment_counter == COUNT_PERIOD) begin
        segment_counter <= 32'd0;
        segment_state <= {segment_state[6:0],segment_state[7]};
      end else begin
        segment_counter <= segment_counter + 1;
        if (segment_state[0] == 1) begin 
            sel_values<= val_in[3:0];
        end else if (segment_state[1] == 1) begin
            sel_values<= val_in[7:4];
        end else if (segment_state[2] == 1) begin
            sel_values<= val_in[11:8];
        end else if (segment_state[3] == 1) begin
            sel_values<= val_in[15:12];
        end else if (segment_state[4] == 1) begin
            sel_values<= val_in[19:16];
        end else if (segment_state[5] == 1) begin
            sel_values<= val_in[23:20];
        end else if (segment_state[6] == 1) begin
            sel_values<= val_in[27:24];
        end else if (segment_state[7] == 1) begin
            sel_values<= val_in[31:28];
      end
      end
    end
  end


endmodule // seven_segment_controller
 
module bto7s(
        input wire [3:0]   x_in,
        output logic [6:0] s_out
        );
logic [15:0] num;
  logic [6:0] sa,sb,sc,sd,se,sf,sg;
        assign num[0] = ~x_in[3] && ~x_in[2] && ~x_in[1] && ~x_in[0];
        assign num[1] = ~x_in[3] && ~x_in[2] && ~x_in[1] && x_in[0];
        assign num[2] = x_in == 4'd2;

        // you do the rest...
        assign num[3] = x_in == 4'd3;
        assign num[4] = x_in == 4'd4;
        assign num[5] = x_in == 4'd5;
        assign num[6] = x_in == 4'd6;
        assign num[7] = x_in == 4'd7;
        assign num[8] = x_in == 4'd8;
        assign num[9] = x_in == 4'd9;
        assign num[10] = x_in == 4'd10;
        assign num[11] = x_in == 4'd11;
        assign num[12] = x_in == 4'd12;
        assign num[13] = x_in == 4'd13;
        assign num[14] = x_in == 4'd14;
        assign num[15] = x_in == 4'd15;


  assign sa = num[0] || num[2] || num[3] || num[5] || num[6] || num[7] || num[8] || num[9] || num[10] || num[12] ||num[14] ||num[15];
  assign sb = num[0] || num[1] || num[2] || num[3] || num[4] || num[7] || num[8] || num[9] || num[10] || num[13];
  assign sc = num[0] || num[1] || num[3] || num[4] || num[5] || num[6] ||num[7] || num[8] || num[9] || num[10] || num[11] || num[13];
  assign sd = num[0] || num[2] || num[3] || num[5] || num[6] || num[8] || num[9] || num[11] || num[12] || num[13] || num[14];
  assign se = num[0] || num[2] || num[6] || num[8] || num[10] || num[11] || num[12] || num[13] || num[14] || num[15];
  assign sf = num[0] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[12] || num[14] || num[15];
  assign sg = num[2] || num[3] || num[4] || num[5] || num[6] || num[8] || num[9] || num[10] || num[11] || num[13] || num[14] || num[15];
  assign s_out = (sg<<6) +(sf<<5)+(se<<4)+(sd<<3)+(sc<<2)+(sb<<1)+sa;

endmodule
 
`default_nettype wire