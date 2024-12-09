import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly, with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

import random

"""
Inputs:
    input wire pixel_clk_in,
    input wire rst_in,

    input wire dda_fifo_tvalid_in,
    input wire [37:0] dda_fifo_tdata_in,
    input wire dda_fifo_tlast_in,
    input wire [1:0] fb_ready_to_switch_in,
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for transformation_tex"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in,1)
    dut.rst_in.value = 0
    await ClockCycles(dut.pixel_clk_in,1)

    for h in range(320):
        line_height = 40
        # if (h<40):  
        #     wall_type = 1
        #     map_data = 1
        #     wallX = int((h/40)*2**8)
        # elif (h<80):
        #     wall_type = 1
        #     map_data = 2
        #     wallX = int((h/80)*2**8)
        # elif (h<120):
        #     wall_type = 1
        #     map_data = 3
        #     wallX = int((h/120)*2**8)
        # elif (h<160):
        #     wall_type = 1
        #     map_data = 4
        #     wallX = int((h/160)*2**8)
        # elif (h<200):
        #     wall_type = 1
        #     map_data = 5
        #     wallX = int((h/200)*2**8)
        # elif (h<240):
        #     wall_type = 1
        #     map_data = 3
        #     wallX = int((h/240)*2**8)
        # elif (h<280):
        #     wall_type = 1
        #     map_data = 4
        #     wallX = int((h/280)*2**8)
        # else:
        #     wall_type = 1
        #     map_data = 5
        #     wallX = int((h/320)*2**8)
        dut.dda_fifo_tvalid_in.value = 1
        dut.dda_fifo_tdata_in.value = (10 << 29) | (180 << 21) | (1 << 20) | (2 << 16) | 4
        dut.dda_fifo_tlast_in.value = 0
        dut.grid_valid_in.value = 1
        await RisingEdge(dut.transformer_tready_out)





    # dut.dda_fifo_tvalid_in.value = 1
    # # dut.dda_fifo_tdata_in.value = 0b11001000_10010110_1_0001_0000111100001111 # hcount = 200, line_height = 150, wall type = 1
    # dut.dda_fifo_tdata_in.value = 0b000000100_00001010_1_0011_0000000011111111 # hcount = 4, line_height = 10, wall type = 1, mapData = 1, WallX = almost full
    # dut.dda_fifo_tlast_in.value = 0

    # # await ClockCycles(dut.pixel_clk_in,100)
    # await RisingEdge(dut.transformer_tready_out) # wait until we're ready to recieve new data

    # dut.dda_fifo_tvalid_in.value = 1
    # # dut.dda_fifo_tdata_in.value = 0b11001000_10010110_1_0001_0000111100001111 # hcount = 200, line_height = 150, wall type = 1
    # dut.dda_fifo_tdata_in.value = 0b000000101_00001001_1_0011_0000111100001111 # hcount = 5, line_height = 9, walltype = 1, mapData = 2
    # dut.dda_fifo_tlast_in.value = 0

    # await RisingEdge(dut.transformer_tready_out) # wait until we're ready to recieve new data

    # dut.dda_fifo_tvalid_in.value = 1
    # # dut.dda_fifo_tdata_in.value = 0b11001000_10010110_1_0001_0000111100001111 # hcount = 200, line_height = 150, wall type = 1
    # dut.dda_fifo_tdata_in.value = 0b000000110_00001000_1_0100_0000111100001111 # hcount = 6, line_height = 8, wallType = 1, mapData = 3
    # dut.dda_fifo_tlast_in.value = 0

    # await RisingEdge(dut.transformer_tready_out)

    # await ClockCycles(dut.pixel_clk_in, 40)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "raycast" / "transformation_tex.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    sources += [proj_path / "hdl" / "raycast" / "textures.sv"]
    sources += [proj_path / "hdl" / "fp" / "divu.sv"]
    sources += [proj_path / "hdl" / "grid_map.sv"]
    build_test_args = ["-Wall"]
    parameters = {"PIXEL_WIDTH": 9,
                  "FULL_SCREEN_WIDTH": 1280,
                  "FULL_SCREEN_HEIGHT": 720,
                  "SCREEN_WIDTH": 320,
                  "SCREEN_HEIGHT": 180}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="transformation_tex",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="transformation_tex",
        test_module="test_transformation_tex",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()