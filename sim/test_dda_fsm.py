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
    """cocotb test for transformation"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.rst_in.value = 0

    # Initialize inputs
    dut.valid_in.value = 0
    dut.dda_fsm_out_tready.value = 0
    dut.map_data_in.value = 0
    dut.map_data_valid_in.value = 0

    # test_data_1 = {
    #     "hcount_ray": 0b0000_0000, # 8-bits :  0 (leftmost pixel on the screen)
    #     "stepX": 0b0, # 1-bit : −1 (since rayDirX < 0)
    #     "stepY": 0b0, # 1-bit : −1 (since rayDirY < 0)
    #     "rayDirX": 0b1111_1111_1111_1111, # 16-bits (8.8) : ??
    #     "rayDirY": 0b1111_1111_1111_1111, # 16-bits (8.8) : ??
    #     "deltaDistX": , # 16-bits (8.8) :
    #     "deltaDistY": , # 16-bits (8.8) :
    #     "posX": 0b0000_1011_0000_0000, # 16-bits (8.8) : 11
    #     "posY": 0b0000_1011_0000_0000, # 16-bits (8.8) : 11
    #     "sideDistX": , # 16-bits (8.8) :
    #     "sideDistY":  # 16-bits (8.8) :
    # }

    # test_data_2 = {
    #     "hcount_ray": 0b1010_0000, # 8-bits : 320/2 = 160
    #     "stepX": 0b1, # 1-bit : 1
    #     "stepY": 0b1, # 1-bit : 1
    #     "rayDirX": 0b1111_1111_1111_1111, # 16-bits (8.8) : ??
    #     "rayDirY": 0b1111_1111_1111_1111, # 16-bits (8.8) : ??
    #     "deltaDistX": , # 16-bits (8.8) :
    #     "deltaDistY": , # 16-bits (8.8) :
    #     "posX": 0b0000_1011_0000_0000, # 16-bits (8.8) : 11
    #     "posY": 0b0000_1011_0000_0000, # 16-bits (8.8) : 11
    #     "sideDistX": , # 16-bits (8.8) :
    #     "sideDistY":  # 16-bits (8.8) :
    # }

    # dda_data_in =


def is_runner():
    """DDA FSM Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "dda_fsm.sv", proj_path / "hdl" / "divu.sv"]
    # sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"SCREEN_WIDTH": 320, "SCREEN_HEIGHT": 240, "N": 24}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="dda_fsm",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="dda_fsm",
        test_module="test_dda_fsm",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
