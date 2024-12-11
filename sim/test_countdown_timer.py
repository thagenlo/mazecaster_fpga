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
    """
    Cocotb test for countdown_timer module
    """
    dut._log.info("Starting countdown_timer test...")

    # Start the clock with a 10ns period (100 MHz clock)
    cocotb.start_soon(Clock(dut.clk_100MHz_in, 10, units="ns").start())

    # Reset the timer
    dut.rst_in.value = 1
    dut.start_timer.value = 0
    await ClockCycles(dut.clk_100MHz_in, 5)  # Wait for reset to propagate
    dut.rst_in.value = 0

    # Verify that the timer initializes to INITIAL_TIME
    # assert dut.time_left.value == dut.INITIAL_TIME.value, \
    #     f"Expected time_left to be {dut.INITIAL_TIME.value}, got {dut.time_left.value}"

    # Start the countdown
    dut.start_timer.value = 1
    await ClockCycles(dut.clk_100MHz_in, 10)  # Allow the start signal to propagate
    dut.start_timer.value = 0

    # Wait for the timer to count down to 0
    for expected_time in range(5 - 1, -1, -1):
        await RisingEdge(dut.clk_1Hz)  # Wait for 1 Hz clock edge
        assert dut.time_left.value == expected_time, \
            f"Expected time_left to be {expected_time}, got {dut.time_left.value}"

    # Verify end_timer signal is asserted
    await RisingEdge(dut.clk_1Hz)

    assert dut.end_timer.value == 1, "end_timer signal was not asserted at the end of the countdown"

    dut._log.info("Countdown_timer test passed!")


def is_runner():
    """timer Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / "misc" / "countdown_timer.sv",
        # proj_path / "hdl" / "raycast" / "dda_fsm.sv",
        # proj_path / "hdl" / "misc" / "evt_counter.sv",
        # proj_path / "hdl" / "fp" / "divu.sv",
    ]
    #sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"INITIAL_TIME": 5}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="countdown_timer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="countdown_timer",
        test_module="test_timer",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
