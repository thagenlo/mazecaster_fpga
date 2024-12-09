module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cathyhu/Documents/GitHub/mazecaster_fpga/sim_build/grid_map.fst");
    $dumpvars(0, grid_map);
end
endmodule
