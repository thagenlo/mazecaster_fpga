module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim_build/game_fsm.fst");
    $dumpvars(0, game_fsm);
end
endmodule
