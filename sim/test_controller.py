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

MOVE_FWD = 0b10  # Forward movement
MOVE_BACK = 0b01  # Backward movement
ROT_LEFT = 0b10  # Rotate left
ROT_RIGHT = 0b01  # Rotate right

@cocotb.test()
async def test_a(dut):
    """cocotb test for controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    # reseting
    dut.rst_in.value = 1
    # dut.moveDir.value = 0
    # dut.rotDir.value = 0
    await RisingEdge(dut.pixel_clk_in)
    dut.rst_in.value = 0

    dut.rotLeft.value = 0
    dut.rotRight.value = 0
    dut.moveFwd.value = 0
    dut.moveBack.value = 0

    await RisingEdge(dut.pixel_clk_in)

    # testing forward movement
    # dut.moveDir.value = MOVE_FWD
    dut.rotLeft.value = 0
    dut.rotRight.value = 0
    dut.moveFwd.value = 1
    dut.moveBack.value = 0
    await RisingEdge(dut.pixel_clk_in)
    dut.rotLeft.value = 0
    dut.rotRight.value = 0
    dut.moveFwd.value = 0
    dut.moveBack.value = 0
    
    await ClockCycles(dut.pixel_clk_in, 100)


    # await RisingEdge(dut.pixel_clk_in)
    # await RisingEdge(dut.pixel_clk_in)
    # # dut.moveDir.value = 0
    # await RisingEdge(dut.pixel_clk_in)

    # # testing bwd movement
    # # dut.moveDir.value = MOVE_BACK
    # await RisingEdge(dut.pixel_clk_in)
    # await RisingEdge(dut.pixel_clk_in)
    # dut.moveDir.value = 0 
    # await RisingEdge(dut.pixel_clk_in)

    # # left rotation
    # dut.rotDir.value = ROT_LEFT
    # await RisingEdge(dut.pixel_clk_in)
    # await RisingEdge(dut.pixel_clk_in)
    # dut.rotDir.value = 0
    # await RisingEdge(dut.pixel_clk_in)

    # # right rotation
    # dut.rotDir.value = ROT_RIGHT
    # await RisingEdge(dut.pixel_clk_in)
    # await RisingEdge(dut.pixel_clk_in)
    # dut.rotDir.value = 0
    # await RisingEdge(dut.pixel_clk_in)
    # await ClockCycles(dut.pixel_clk_in, 100)




def controller_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "controller.sv", proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="controller",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="controller",
        test_module="test_controller",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    controller_runner()