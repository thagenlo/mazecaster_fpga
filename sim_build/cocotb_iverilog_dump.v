module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim_build/controller.fst");
    $dumpvars(0, controller);
end
endmodule
