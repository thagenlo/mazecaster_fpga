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
    input wire [10:0] hcount_in, // from video_sig_gen
    input wire [9:0] vcount_in,
    input wire [15:0] address_in, // from transformating / flattening module (not in order and ranges from 0 to 320*180)
    input wire [15:0] pixel_in,
    input wire ray_last_pixel_in, // indicates the last computed pixel in the ray sweep
    input wire video_last_pixel_in, // indicates the last
Test:
    - video_sig_gen 
        request hcount, vcount data on every pixel block rising edge
    - ray data in
        input ray data (address_in and pixel_in) at a random rate, in a random order
        address_in generated from random()
        
"""

@cocotb.test()
async def test_a(dut):
    """cocotb test for frame_buffer"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())
    dut.rst_in.value = 1
    await ClockCycles(dut.pixel_clk_in,1)
    dut.rst_in.value = 0
    for _ in range(2): # repeat two times
        video_counter = 0
        ray_counter = 0
        list_of_ray_addresses_left = [i for i in range(5*10)]
        # first time there should be nothing to request (pixel out should be 0)
        # second time it should show the values of the ray casted pixel input at the corresponding address
        for v in range(20):
            for h in range(40):
                dut.hcount_in.value = h
                dut.vcount_in.value = v
                video_counter += 1
                # choose random value between 1 and 10 to take mod of, so that the rate at which ray pixels are added is truly random
                x = random.choice([i for i in range(1,10)])
                if (h%x == 0 and list_of_ray_addresses_left):
                    random_address = random.choice(list_of_ray_addresses_left)
                    list_of_ray_addresses_left.remove(random_address)
                    dut.address_in.value = random_address # random address in range = [0, 320*180]
                    dut.pixel_in.value = random.choice([i for i in range(2**16)]) # random pixel value in range = [0, 65535]
                    # ray_counter += 1
                # if (v%4 == 0 and h%4 == 0):
                    # dut.address_in.value = (h//4)+(v//4)*10
                    # dut.pixel_in.value = h//4
                await ClockCycles(dut.pixel_clk_in, 1)
        # video_last_pixel_in: one cycle high to indicate we're done outputting the frame onto the screen
        dut.video_last_pixel_in.value = 1
        await ClockCycles(dut.pixel_clk_in, 1)
        dut.video_last_pixel_in.value = 0

        # finish filling the ray casted pixel values into the frame buffer
        while (list_of_ray_addresses_left):
            # ray_counter += 1
            random_address = random.choice(list_of_ray_addresses_left)
            list_of_ray_addresses_left.remove(random_address)
            dut.address_in.value = random_address # random address in range = [0, 320*180]
            dut.pixel_in.value = random.choice([i for i in range(2**16)]) # random pixel value in range = [0, 65535]
            # dut.address_in = random.choice([i for i in range(320*180)]) # random address in range = [0, 320*180]
            # dut.pixel_in = random.choice([i for i in range(2**16)]) # random pixel value in range = [0, 65535]
            await ClockCycles(dut.pixel_clk_in, 1)

        # ray_last_pixel_in: one cycle high to indicate we're done filling the frame buffer with freshly calculated values
        dut.ray_last_pixel_in.value = 1
        await ClockCycles(dut.pixel_clk_in, 1)
        dut.ray_last_pixel_in.value = 0
        # await ClockCycles(dut.pixel_clk_in, 2)


    """
    for _ in range(2):
        video_counter = 0
        ray_counter = 0
        break_out = 0
        for v in range(720):
            if break_out == 1: 
                break
            for h in range(1280):
                if video_counter < 320*180:
                    video_counter += 1
                else: 
                    video_counter = 0
                    break_out = 1
                    break
                dut.hcount_in = h
                dut.vcount_in = v
                if (video_counter % 3 == 0 or video_counter % 5 == 0): # making ray address + pixel sent in somewhat random
                    ray_counter += 1
                    dut.address_in = random.choice([i for i in range(320*180)]) # random address in range = [0, 320*180]
                    dut.pixel_in = random.choice([i for i in range(2**16)]) # random pixel value in range = [0, 65535]
                await ClockCycles(dut.pixel_clk_in, 1)
        while (ray_counter < 320*180):
            ray_counter += 1
            dut.address_in = random.choice([i for i in range(320*180)]) # random address in range = [0, 320*180]
            dut.pixel_in = random.choice([i for i in range(2**16)]) # random pixel value in range = [0, 65535]
            await ClockCycles(dut.pixel_clk_in, 1)
    """

    await ClockCycles(dut.pixel_clk_in, 2)


def is_runner():
    """Image Sprite Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "frame_buffer.sv"]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"PIXEL_WIDTH": 16,
                  "FULL_SCREEN_WIDTH": 40,
                  "FULL_SCREEN_HEIGHT": 20,
                  "SCREEN_WIDTH": 10,
                  "SCREEN_HEIGHT": 5}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="frame_buffer",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="frame_buffer",
        test_module="test_frame_buffer1",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    is_runner()