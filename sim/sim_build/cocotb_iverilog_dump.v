module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cathyhu/Documents/GitHub/mazecaster_fpga/sim/sim_build/transformation_tex.fst");
    $dumpvars(0, transformation_tex);
end
endmodule
