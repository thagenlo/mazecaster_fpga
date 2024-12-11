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
input wire pixel_clk_in,
input wire rst_in,
input wire valid_req_in,
input wire [15:0] wallX_in,
input wire [7:0] lineheight_in,
input wire [9:0] drawstart_in,
input wire [7:0] vcount_ray_in,
input wire [4:0] texture_in, // which texture (map_data)
output logic [7:0] tex_pixel_out,
output logic valid_tex_out
    
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for textures"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in,1)
    dut.rst_in.value = 0
    dut.valid_req_in.value = 1
    dut.wallX_in.value = 0b00000000_00110000
    dut.lineheight_in.value = 80
    dut.drawstart_in.value = 50
    dut.vcount_ray_in.value = 66
    dut.texture_in.value = 20
    await ClockCycles(dut.pixel_clk_in,30)

    


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "raycast" / "textures.sv"]
    sources += [proj_path / "hdl" / "fp" / "divu.sv"]
    # sources += [proj_path / "hdl" / "divu.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="textures",
        always=True,
        build_args=build_test_args,
        # parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="textures",
        test_module="test_textures",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()