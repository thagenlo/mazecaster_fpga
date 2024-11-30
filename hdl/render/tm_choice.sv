module tm_choice (
  input wire [7:0] data_in,
  output logic [8:0] qm_out
  );

  logic [7:0] num_of_ones;
  always_comb begin
    qm_out[0] = data_in[0];
    // check if number of 1's (sum together all bits that are 1)
    num_of_ones = 0;
    for (int i = 0; i < 8; i = i + 1) begin
        num_of_ones = num_of_ones + data_in[i];
    end
    // num_of_ones = data_in[0] + data_in[1] + data_in[2] + data_in[3]+ data_in[4]+ data_in[5]+ data_in[6] + data_in[7];
    if ((num_of_ones > 4) || ((num_of_ones == 4) && (data_in[0] == 0))) begin // option 2
        for (int i = 1; i < 8; i = i + 1) begin
            qm_out[i] = ~(data_in[i] ^ qm_out[i-1]);
        end
        // qm_out[1] = ~(data_in[1] ^ qm_out[0]);
        // qm_out[2] = ~(data_in[2] ^ qm_out[1]);
        // qm_out[3] = ~(data_in[3] ^ qm_out[2]);
        // qm_out[4] = ~(data_in[4] ^ qm_out[3]);
        // qm_out[5] = ~(data_in[5] ^ qm_out[4]);
        // qm_out[6] = ~(data_in[6] ^ qm_out[5]);
        // qm_out[7] = ~(data_in[7] ^ qm_out[6]);
        qm_out[8] = 0;
    end else begin
        for (int i = 1; i < 8; i = i + 1) begin
            qm_out[i] = (data_in[i] ^ qm_out[i-1]);
        end
        // qm_out[1] = (data_in[1] ^ qm_out[0]);
        // qm_out[2] = (data_in[2] ^ qm_out[1]);
        // qm_out[3] = (data_in[3] ^ qm_out[2]);
        // qm_out[4] = (data_in[4] ^ qm_out[3]);
        // qm_out[5] = (data_in[5] ^ qm_out[4]);
        // qm_out[6] = (data_in[6] ^ qm_out[5]);
        // qm_out[7] = (data_in[7] ^ qm_out[6]);
        qm_out[8] = 1;
    end
  end
 
endmodule