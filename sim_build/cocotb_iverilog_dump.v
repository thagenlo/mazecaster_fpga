module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/heba/Documents/GitHub/mazecaster_fpga/sim_build/btn_control.fst");
    $dumpvars(0, btn_control);
end
endmodule
