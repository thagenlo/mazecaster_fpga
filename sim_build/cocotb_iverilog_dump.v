module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cathyhu/Documents/GitHub/mazecaster_fpga/sim_build/transformation.fst");
    $dumpvars(0, transformation);
end
endmodule
