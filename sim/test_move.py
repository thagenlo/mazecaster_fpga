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
    await ClockCycles(dut.clk_in, 2)
    dut.rst_in.value = 0
    await RisingEdge(dut.clk_in)

    dut.fwd_pulse.value = 0 # POSY = 0b80 (init)
    dut.bwd_pulse.value = 0
    dut.leftRot_pulse.value = 0
    dut.rightRot_pulse.value = 0

    await RisingEdge(dut.clk_in)
    dut.is_pulse.value = 0
    await RisingEdge(dut.clk_in)

    # testing forward movement (moving in negative Y)
    dut.is_pulse.value = 1
    dut.fwd_pulse.value = 1 
    await RisingEdge(dut.clk_in) #0a80 for posY
    dut.fwd_pulse.value = 0
    dut.is_pulse.value = 0
    await ClockCycles(dut.clk_in, 10)

    # testing forward movement (moving in negative Y)
    dut.is_pulse.value = 1
    dut.fwd_pulse.value = 1 #0980
    await RisingEdge(dut.clk_in)
    dut.fwd_pulse.value = 0
    dut.is_pulse.value = 0
    await ClockCycles(dut.clk_in, 10)

    # testing bwd movement (moving in positive Y)
    dut.is_pulse.value = 1
    dut.bwd_pulse.value = 1 #0a80
    await RisingEdge(dut.clk_in)
    dut.is_pulse.value = 0
    dut.bwd_pulse.value = 0
    await ClockCycles(dut.clk_in, 10)

    #LEFT ROT: 
    # double oldDirX = dirX;
    # dirX = dirX * cos(rotSpeed) - dirY * sin(rotSpeed);
    # dirY = oldDirX * sin(rotSpeed) + dirY * cos(rotSpeed);
    # double oldPlaneX = planeX;
    # planeX = planeX * cos(rotSpeed) - planeY * sin(rotSpeed);
    # planeY = oldPlaneX * sin(rotSpeed) + planeY * cos(rotSpeed);
    # [dirX, dirY, planeX, planeY] = [00B5, FF4B, 0077, 0077] (expected values)

    await RisingEdge(dut.clk_in)
    dut.is_pulse.value = 1 
    dut.leftRot_pulse.value = 1 
    await RisingEdge(dut.clk_in) 
    dut.leftRot_pulse.value = 0
    dut.is_pulse.value = 0
    await ClockCycles(dut.clk_in, 10)

    # RIGHT ROT:
    # double oldDirX = dirX;
    # dirX = dirX * cos(-rotSpeed) - dirY * sin(-rotSpeed);
    # dirY = oldDirX * sin(-rotSpeed) + dirY * cos(-rotSpeed);
    # double oldPlaneX = planeX;
    # planeX = planeX * cos(-rotSpeed) - planeY * sin(-rotSpeed);
    # planeY = oldPlaneX * sin(-rotSpeed) + planeY * cos(-rotSpeed);
    # [dirX, dirY, planeX, planeY] = [0000, FF00, 0a90, 0000] (expected values)
    await RisingEdge(dut.clk_in)
    dut.is_pulse.value = 1
    dut.rightRot_pulse.value = 1 
    await RisingEdge(dut.clk_in)
    dut.is_pulse.value = 0
    dut.rightRot_pulse.value = 0
    await ClockCycles(dut.clk_in, 10)



def controller_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "controls" / "btn_control.sv", proj_path / "hdl" / "controls" / "movement_control.sv"]
    build_test_args = ["-Wall"]
    parameters = {}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="movement_control",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="movement_control",
        test_module="test_move",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    controller_runner()