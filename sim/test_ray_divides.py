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
    cocotb.start_soon(Clock(dut.pixel_clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    await ClockCycles(dut.pixel_clk_in, 2)
    # reseting
    dut.rst_in.value = 1
    await RisingEdge(dut.pixel_clk_in)
    dut.rst_in.value = 0

    await ClockCycles(dut.pixel_clk_in, 2)

    #-3.53 should be the answer

    # cameraX should be .25 = 0000000001000000
    # planeX should be 16'b0000000010101001; //.66 -> 0.66015625
    # rayDir should be 16'b0000000100101010; 1.16504 -> 1.1640625
        # getting 1.17578125
    #

    await RisingEdge(dut.pixel_clk_in)
    await RisingEdge(dut.pixel_clk_in)
    dut.posX.value = 0b0001_0110_1000_0000 #22.5
    dut.dirX.value = 0b000_0001_0000_0000 # 1 
    dut.planeX.value = 0b0000_0000_1010_1001 # .66
    dut.hcount_in.value = 0b11001000 #200

    await ClockCycles(dut.pixel_clk_in, 100)





def divider_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "testing_u_divider.sv", proj_path / "hdl" / "divider.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="testing_u_divider",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="testing_u_divider",
        test_module="test_ray_divides",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    divider_runner()