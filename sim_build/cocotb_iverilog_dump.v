module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim_build/testing_u_divider.fst");
    $dumpvars(0, testing_u_divider);
end
endmodule
