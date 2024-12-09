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

    input wire [1:0] map_select, // 0, 1, 2, 3 (4 maps)
    input wire dda_req_in,
    input wire trans_req_in,
    input wire [15:0] dda_address_in,
    input wire [15:0] trans_address_in,

    output logic dda_valid_out,
    output logic trans_valid_out,

    output logic [3:0] grid_data
        
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for grid_map"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in,1)
    dut.rst_in.value = 0
    # await ClockCycles(dut.pixel_clk_in,1)
    dut.map_select.value = 0
    dut.trans_req_in.value = 1
    dut.trans_address_in.value = 4
    # await ClockCycles(dut.pixel_clk_in,10)
    await RisingEdge(dut.trans_valid_out)
    dut.trans_req_in.value = 0
    await ClockCycles(dut.pixel_clk_in,1)
    dut.map_select.value = 0
    dut.trans_req_in.value = 1
    dut.trans_address_in.value = 0
    await ClockCycles(dut.pixel_clk_in,10)

def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "grid_map.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    # parameters = {"PIXEL_WIDTH": 16,
    #               "FULL_SCREEN_WIDTH": 120,
    #               "FULL_SCREEN_HEIGHT": 80,
    #               "SCREEN_WIDTH": 30,
    #               "SCREEN_HEIGHT": 20}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="grid_map",
        always=True,
        build_args=build_test_args,
        # parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="grid_map",
        test_module="test_grid_map",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()