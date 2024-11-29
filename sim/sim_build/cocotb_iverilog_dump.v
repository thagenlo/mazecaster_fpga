module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim/sim_build/ray_calculations.fst");
    $dumpvars(0, ray_calculations);
end
endmodule
