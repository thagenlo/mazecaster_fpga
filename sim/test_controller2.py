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
    """cocotb test for controller"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    # reseting
    dut.rst_in.value = 1
    # dut.moveDir.value = 0
    # dut.rotDir.value = 0
    await ClockCycles(dut.clk_in, 2)
    dut.rst_in.value = 0
    dut.frame_switch.value = 0
    await RisingEdge(dut.clk_in)

    dut.fwd_btn.value = 0
    dut.bwd_btn.value = 0
    dut.leftRot_btn.value = 0
    dut.rightRot_btn.value = 0

    await RisingEdge(dut.clk_in)
    # dut.valid_in.value = 1

    #base case: looking forward

    # testing forward movement
    dut.fwd_btn.value = 1 # POS Y SHOULD BECOME #0a80
    await RisingEdge(dut.clk_in)
    dut.fwd_btn.value = 0
    await ClockCycles(dut.clk_in, 10)

    dut.fwd_btn.value = 1 # POS Y SHOULD BECOME #0980
    await RisingEdge(dut.clk_in)
    dut.fwd_btn.value = 0
    await ClockCycles(dut.clk_in, 10)

    dut.bwd_btn.value = 1 # POS Y SHOULD BECOME #0a80
    await RisingEdge(dut.clk_in)
    dut.bwd_btn.value = 0
    await ClockCycles(dut.clk_in, 10)

    dut.frame_switch.value = 1
    await RisingEdge(dut.clk_in)
    dut.frame_switch.value = 0

    await RisingEdge(dut.clk_in)
    dut.leftRot_btn.value = 1 # DIR X SHOULD BECOME 0xFFA5, DIR X SHOULD BECOME 0xFFA5,
    await RisingEdge(dut.clk_in)
    dut.leftRot_btn.value = 0
    await ClockCycles(dut.clk_in, 2)

    dut.frame_switch.value = 1
    await RisingEdge(dut.clk_in)
    dut.frame_switch.value = 0
    await RisingEdge(dut.clk_in)

    dut.leftRot_btn.value = 1
    await ClockCycles(dut.clk_in, 2)
    dut.leftRot_btn.value = 0
    await ClockCycles(dut.clk_in, 10)

    #rotating left 
    dut.leftRot_btn.value = 1 
    await RisingEdge(dut.clk_in, 2)
    # dut.is_pulse.value = 0
    dut.leftRot_btn.value = 0
    await ClockCycles(dut.clk_in, 10)

    dut.frame_switch.value = 1
    await RisingEdge(dut.clk_in)
    dut.frame_switch.value = 0

    await RisingEdge(dut.clk_in)

    #rotating right (original position)
    dut.rightRot_btn.value = 1
    await RisingEdge(dut.clk_in)
    dut.rightRot_btn.value = 0
    await ClockCycles(dut.clk_in, 10)




def controller_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "controls" / "btn_control.sv", proj_path / "hdl" / "controls" / "movement_control.sv", proj_path / "hdl" / "controls" / "debouncer.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="btn_control",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="btn_control",
        test_module="test_controller2",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    controller_runner()