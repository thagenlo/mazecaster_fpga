module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cathyhu/Documents/GitHub/mazecaster_fpga/sim_build/timer.fst");
    $dumpvars(0, timer);
end
endmodule
