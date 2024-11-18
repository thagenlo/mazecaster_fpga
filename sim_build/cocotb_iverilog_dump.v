module cocotb_iverilog_dump();
initial begin
    $dumpfile("/Users/cathyhu/Documents/GitHub/mazecaster_fpga/sim_build/frame_buffer.fst");
    $dumpvars(0, frame_buffer);
end
endmodule
