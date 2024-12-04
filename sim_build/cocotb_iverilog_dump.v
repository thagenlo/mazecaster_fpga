module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim_build/multiply.fst");
    $dumpvars(0, multiply);
end
endmodule
