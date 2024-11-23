module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/victoriahagenlocker/Documents/Documents - Victoria’s MacBook Air/GitHub/mazecaster_fpga/sim/sim_build/dda_fsm.fst");
    $dumpvars(0, dda_fsm);
end
endmodule
