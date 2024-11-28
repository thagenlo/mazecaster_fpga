module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim/sim_build/test_raycaster2.fst");
    $dumpvars(0, test_raycaster2);
end
endmodule
