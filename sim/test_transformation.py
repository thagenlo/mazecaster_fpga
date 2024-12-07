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

    output logic transformer_tready_out,         // tells FIFO that we're ready to receive next data (need a vcount counter)
    // output logic fb_ready_out,
    output logic [15:0] ray_address_out,    // where to store the pixel value in frame buffer
    output logic [15:0] ray_pixel_out,      // the calculated pixel value of the ray
    output logic ray_last_pixel_out        // tells frame buffer whether we are on the last pixel or not
        
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for transformation"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in,1)
    dut.rst_in.value = 0
    await ClockCycles(dut.pixel_clk_in,1)
    line_height = 40
    wall_type = 1
    map_data = 1
    wallX = 20

    dut.dda_fifo_tvalid_in.value = 1
    dut.dda_fifo_tdata_in.value = (1 << 29) | (line_height << 21) | (wall_type << 20) | (map_data << 16) | wallX
    dut.dda_fifo_tlast_in.value = 0

    await RisingEdge(dut.transformer_tready_out)

    dut.dda_fifo_tvalid_in.value = 1
    dut.dda_fifo_tdata_in.value = (2 << 29) | (line_height << 21) | (wall_type << 20) | (map_data << 16) | wallX
    dut.dda_fifo_tlast_in.value = 1

    await ClockCycles(dut.pixel_clk_in, 100)
    dut.fb_ready_to_switch_in.value = 3
    await RisingEdge(dut.transformer_tready_out)

    dut.dda_fifo_tvalid_in.value = 1
    dut.dda_fifo_tdata_in.value = (1 << 29) | (line_height << 21) | (wall_type << 20) | (map_data << 16) | wallX
    dut.dda_fifo_tlast_in.value = 0
    await RisingEdge(dut.transformer_tready_out)
    
    # # go through one round of flattening for a whole screen
    # for h in range(320):
    #     dut.dda_fifo_tvalid_in.value = 1
    #     dut.dda_fifo_tdata_in.value = (h << 29) | (line_height << 21) | (wall_type << 20) | (map_data << 16) | wallX
    #     if (h == 319):
    #         dut.dda_fifo_tlast_in.value = 1
    #     else:
    #         dut.dda_fifo_tlast_in.value = 0
    #     await RisingEdge(dut.transformer_tready_out)

    # # fifo out becomes valid
    # await ClockCycles(dut.pixel_clk_in, 2)
    # dut.dda_fifo_tvalid_in.value = 1
    # dut.dda_fifo_tlast_in.value = 0
    # dut.dda_fifo_tdata_in.value = (0 << 29) | (line_height << 21) | (wall_type << 20) | (map_data << 16) | wallX

    # # we are finally ready to switch frame buffers and start writing to the new one
    # await ClockCycles(dut.pixel_clk_in, 20)
    # dut.fb_ready_to_switch_in.value = 3
    # await RisingEdge(dut.transformer_tready_out)

    # for h in range(1, 320):
    #     dut.dda_fifo_tvalid_in.value = 1
    #     dut.dda_fifo_tdata_in.value = (h << 29) | (line_height << 21) | (wall_type << 20) | (map_data << 16) | wallX
    #     if (h == 319):
    #         dut.dda_fifo_tlast_in.value = 1
    #     else:
    #         dut.dda_fifo_tlast_in.value = 0
    #     await RisingEdge(dut.transformer_tready_out)

def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "raycast" / "transformation.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"PIXEL_WIDTH": 16,
                  "FULL_SCREEN_WIDTH": 120,
                  "FULL_SCREEN_HEIGHT": 80,
                  "SCREEN_WIDTH": 30,
                  "SCREEN_HEIGHT": 20}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="transformation",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="transformation",
        test_module="test_transformation",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()