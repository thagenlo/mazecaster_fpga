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
    input wire clk_100mhz_in,
    input wire rst_in,
    input wire start_timer_in,

    output logic [9:0] time_out,
    output logic timer_done_out
        
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for timer"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_100mhz_in, 10, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.clk_100mhz_in,1)
    dut.rst_in.value = 0
    await ClockCycles(dut.clk_100mhz_in,2)

    # start timer
    dut.start_timer_in.value = 1
    await ClockCycles(dut.clk_100mhz_in,1)
    dut.start_timer_in.value = 0

    # wait for a long time
    await ClockCycles(dut.clk_100mhz_in,1000) # 1 second
    


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "timer.sv"]
    build_test_args = ["-Wall"]
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="timer",
        always=True,
        build_args=build_test_args,
        # parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="timer",
        test_module="test_timer",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()