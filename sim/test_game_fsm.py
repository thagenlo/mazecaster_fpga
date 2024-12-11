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

# MOVE_FWD = 0b10  # Forward movement
# MOVE_BACK = 0b01  # Backward movement
# ROT_LEFT = 0b10  # Rotate left
# ROT_RIGHT = 0b01  # Rotate right

@cocotb.test()
async def test_a(dut):
    """cocotb test..."""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    # reseting
    dut.rst_in.value = 1
    # dut.moveDir.value = 0
    # dut.rotDir.value = 0
    await ClockCycles(dut.clk_in, 2)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    dut.sw.value = 0b100_0000
    await ClockCycles(dut.clk_in, 4)
    dut.sw.value = 0b10_0000
    dut.btn.value = 0b0010

    await ClockCycles(dut.clk_in, 10)

    dut.posX.value = 1
    dut.posY.value = 2

    await ClockCycles(dut.clk_in, 10)

    dut.posX.value = 3
    dut.posY.value = 4

    await ClockCycles(dut.clk_in, 5)

    await ClockCycles(dut.clk_in, 5)

    dut.posX.value = 5
    dut.posY.value = 6

    await ClockCycles(dut.clk_in, 1000)


    # dut.fwd_btn.value = 1 # POS Y SHOULD BECOME #0980
    # await RisingEdge(dut.clk_in)
    # dut.fwd_btn.value = 0
    # await ClockCycles(dut.clk_in, 10)




def game_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "game_fsm.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="game_fsm",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="game_fsm",
        test_module="test_game_fsm",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    game_runner()