module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cathyhu/Documents/GitHub/mazecaster_fpga/sim/sim_build/textures.fst");
    $dumpvars(0, textures);
end
endmodule
