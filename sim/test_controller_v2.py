import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import (
    Timer,
    ClockCycles,
    RisingEdge,
    FallingEdge,
    ReadOnly,
    with_timeout,
)
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

import random


@cocotb.test()
async def test_a(dut):
    # """cocotb test for dda"""
    # dut._log.info("Starting...")
    # cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())

    # dut.rst_in.value = 1
    # dut.dda_fsm_in_tvalid.value = 1  # FIFO has valid data for the receiver to consume
    # dut.dda_fsm_out_tready.value = 1  # FIFO is ready to accept data from the sender
    # await ClockCycles(dut.pixel_clk_in, 5)
    # dut.rst_in.value = 0

    # Start the clock
    cocotb.start_soon(Clock(dut.clk_in, 13.47, units="ns").start())  # 100 MHz clock

    # Apply reset
    dut.rst_in.value = 1
    await Timer(100, units="ns")  # Wait for reset to propagate
    dut.rst_in.value = 0

    # Initialize inputs
    dut.btn.value = 0b0000  # No buttons pressed
    dut.fwd_btn.value = 0
    dut.bwd_btn.value = 0
    dut.leftRot_btn.value = 0
    dut.rightRot_btn.value = 0

    # Wait for a clock edge to synchronize
    await RisingEdge(dut.clk_in)

    # Test forward button
    dut.fwd_btn.value = 1
    # await RisingEdge(dut.clk_in)
    await Timer(500, units="ns")  # debounce time - 5 millisec
    dut.fwd_btn.value = 0
    await RisingEdge(dut.clk_in)

    await Timer(50, units="ns")  # Wait for reset to propagate

    # Test backward button
    dut.bwd_btn.value = 1
    # await RisingEdge(dut.clk_in)
    await Timer(500, units="ns")  # debounce time - 5 millisec
    dut.bwd_btn.value = 0
    await RisingEdge(dut.clk_in)

    await Timer(50, units="ns")  # Wait for reset to propagate

    # Test left rotation
    dut.leftRot_btn.value = 1
    # await RisingEdge(dut.clk_in)
    await Timer(500, units="ns")  # debounce time - 5 millisec
    dut.leftRot_btn.value = 0
    await RisingEdge(dut.clk_in)

    await Timer(50, units="ns")  # Wait for reset to propagate

    # Test right rotation
    dut.rightRot_btn.value = 1
    # await RisingEdge(dut.clk_in)
    await Timer(500, units="ns")  # debounce time - 5 millisec
    dut.rightRot_btn.value = 0
    await RisingEdge(dut.clk_in)

    await Timer(500, units="ns")  # Wait for reset to propagate

    dut._log.info("Test completed successfully!")


def is_runner():
    """DDA FSM Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / "controls" / "test_controls.sv",
        proj_path / "hdl" / "controls" / "debouncer.sv",
        proj_path / "hdl" / "controls" / "button_control.sv",
        proj_path / "hdl" / "controls" / "dir_pos_control.sv",
    ]
    # sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"ROTATION_ANGLE": 0x2D00}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="test_controls",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="test_controls",
        test_module="test_controller_v2",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
