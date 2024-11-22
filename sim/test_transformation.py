import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly, with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

import random

"""
Inputs:
    input wire pixel_clk_in,
    input wire rst_in,

    input wire dda_fifo_tvalid_in,
    input wire [37:0] dda_fifo_tdata_in, = 9 (hcount) + 8 (line height) + 1 (wall type) + 4 (map data) + 16 (wallX)
    input wire dda_fifo_tlast_in,

    output logic transformer_tready_out,         // tells FIFO that we're ready to receive next data (need a vcount counter)

    output logic [15:0] ray_address_out,    // where to store the pixel value in frame buffer
    output logic [15:0] ray_pixel_out,      // the calculated pixel value of the ray
    output logic ray_last_pixel_out,        // tells frame buffer whether we are on the last pixel or not
        
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for transformation"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in,1)
    dut.rst_in.value = 0
    
    dut.dda_fifo_tvalid_in.value = 1
    # dut.dda_fifo_tdata_in.value = 0b11001000_10010110_1_0001_0000111100001111 # hcount = 200, line_height = 150, wall type = 1
    dut.dda_fifo_tdata_in.value = 0b00000100_00001010_1_0001_0000111100001111 # hcount = 4, line_height = 10
    dut.dda_fifo_tlast_in = 0

    await RisingEdge(dut.transformer_tready_out) # wait until we're ready to recieve new data

    dut.dda_fifo_tvalid_in.value = 1
    # dut.dda_fifo_tdata_in.value = 0b11001000_10010110_1_0001_0000111100001111 # hcount = 200, line_height = 150, wall type = 1
    dut.dda_fifo_tdata_in.value = 0b00000101_00001001_1_0001_0000111100001111 # hcount = 5, line_height = 9
    dut.dda_fifo_tlast_in = 0

    await RisingEdge(dut.transformer_tready_out) # wait until we're ready to recieve new data

    dut.dda_fifo_tvalid_in.value = 1
    # dut.dda_fifo_tdata_in.value = 0b11001000_10010110_1_0001_0000111100001111 # hcount = 200, line_height = 150, wall type = 1
    dut.dda_fifo_tdata_in.value = 0b00000110_00001000_1_0001_0000111100001111 # hcount = 6, line_height = 8
    dut.dda_fifo_tlast_in = 0

    await RisingEdge(dut.transformer_tready_out)

    # await ClockCycles(dut.pixel_clk_in, 40)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "transformation.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"PIXEL_WIDTH": 16,
                  "FULL_SCREEN_WIDTH": 120,
                  "FULL_SCREEN_HEIGHT": 80,
                  "SCREEN_WIDTH": 30,
                  "SCREEN_HEIGHT": 20}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="transformation",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="transformation",
        test_module="test_transformation",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()