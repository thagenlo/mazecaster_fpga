module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim_build/movement_control.fst");
    $dumpvars(0, movement_control);
end
endmodule
