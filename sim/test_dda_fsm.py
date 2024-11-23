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
    """cocotb test for dda fsm"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.rst_in.value = 0

    dut.valid_in.value = 0
    dut.dda_fsm_out_tready.value = 1
    dut.map_data_valid_in.value = 0
    dut.map_data_in.value = 0

    test_data_1 = {
        "hcount_ray": 0b0000_0000,  # 8-bits :  0 (leftmost pixel on the screen)
        "stepX": 0b0,  # 1-bit : −1 (since rayDirX < 0)
        "stepY": 0b0,  # 1-bit : −1 (since rayDirY < 0)
        "rayDirX": 0b1111_1111_1111_1111,  # 16-bits (8.8) : −1.0 TODO later
        "rayDirY": 0b1111_1111_1111_1111,  # 16-bits (8.8) : −0.66 TODO later
        "deltaDistX": 0b0000_0001_0000_0000,  # 16-bits (8.8) : 1 = abs(1/rayDirX)
        "deltaDistY": 0b0000_0001_1000_0100,  # 16-bits (8.8) : 1.515625 = ~1.51515151515 = abs(1/rayDirY)
        "posX": 0b0000_1011_1000_0000,  # 16-bits (8.8) : 11.5
        "posY": 0b0000_1011_1000_0000,  # 16-bits (8.8) : 11.5
        "sideDistX": 0b0000_0000_1000_0000,  # 16-bits (8.8) : 0.5 = (posX - mapX) * deltaDistX;
        "sideDistY": 0b0000_0000_1100_0010,  # 16-bits (8.8) : 0.7578125  = ~0.7578125 = (posY - mapY) * deltaDistY;
    }

    dda_data_in1 = (
        ((test_data_1["hcount_ray"] & 0x1FF) << 130)  # Mask to 9 bits
        | ((test_data_1["stepX"] & 0x1) << 129)  # Mask to 1 bit
        | ((test_data_1["stepY"] & 0x1) << 128)  # Mask to 1 bit
        | ((test_data_1["rayDirX"] & 0xFFFF) << 112)  # Mask to 16 bits
        | ((test_data_1["rayDirY"] & 0xFFFF) << 96)  # Mask to 16 bits
        | ((test_data_1["deltaDistX"] & 0xFFFF) << 80)  # Mask to 16 bits
        | ((test_data_1["deltaDistY"] & 0xFFFF) << 64)  # Mask to 16 bits
        | ((test_data_1["posX"] & 0xFFFF) << 48)  # Mask to 16 bits
        | ((test_data_1["posY"] & 0xFFFF) << 32)  # Mask to 16 bits
        | ((test_data_1["sideDistX"] & 0xFFFF) << 16)  # Mask to 16 bits
        | ((test_data_1["sideDistY"] & 0xFFFF))  # Mask to 16 bits
    )

    # dda_data_in_1 = format(dda_data_in1, '#0141b')  # 139 bits + 2 for "0b"
    print(f"dda_data_in: {dda_data_in1}")

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
    dut.dda_data_in.value = dda_data_in1

    dut.valid_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.valid_in.value = 0

    # first req is 0
    await RisingEdge(dut.map_request_out)
    dut.map_data_in.value = 0
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.map_data_valid_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.map_data_valid_in.value = 0

    # second req is 0
    await RisingEdge(dut.map_request_out)
    dut.map_data_in.value = 0
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.map_data_valid_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.map_data_valid_in.value = 0

    # third req is 1
    await RisingEdge(dut.map_request_out)
    dut.map_data_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.map_data_valid_in.value = 1
    await ClockCycles(dut.pixel_clk_in, 1)
    dut.map_data_valid_in.value = 0

    await RisingEdge(dut.dda_valid_out)
    await FallingEdge(dut.dda_valid_out)

    # for _ in range(10):  # Monitor FSM for 50 clock cycles
    #     await Timer(10, "ns")
    #     print(f"Time: {gst()} | FSM State: {dut.DDA_FSM_STATE.value}")

    # await with_timeout(RisingEdge(dut.dda_valid_out), 100000000, units="ns")


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
