module timer (
    input wire clk_100mhz_in,
    input wire rst_in,

    input wire [9:0] max_sec_in,

    output logic [9:0] time_out
)

/*
input wire          clk_in,
input wire          rst_in,
input wire [1:0]    evt_in,     // multi-bit input to support increments >1
output logic[$clog2(MAX_COUNT)-1:0]  count_out
*/

// evt_counter#(
//     .MAX_COUNT(max_sec_in)
// ) (
//     .clk_in(clk_)
// )

// endmodule