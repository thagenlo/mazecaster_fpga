import cocotb
import os
import random
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

@cocotb.test()
async def test_a(dut):
    """cocotb test for controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    # reseting
    dut.rst_in.value = 1
    await RisingEdge(dut.clk_in)
    dut.rst_in.value = 0

    await ClockCycles(dut.clk_in, 2)

    # testing -7.0625/2 
    # -7 -> 11111001
    dut.a.value = 0b11111000_11110000
    dut.b.value = 0b00000010_00000000
    dut.start.value = 1
    #-3.53 should be the answer
    #  -3.53125 -> 1111110001111000

    await RisingEdge(dut.clk_in)
    dut.start.value = 0

    while not dut.done.value:
        await RisingEdge(dut.clk_in)

    await ClockCycles(dut.clk_in, 10)





def divider_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "divider.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="divider",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="divider",
        test_module="test_divider",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    divider_runner()