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
import math

# Constants
screen_width = 320
# posX = 11.5
# posY = 11.5
dirX = -0.707106 #-1.0
dirY = 0.707106 #0.0
planeX = 0.46669 # 0.0
planeY = 0.46669 # 0.66


def to_fixed(value, fraction_bits=8, total_bits=16):
    """Convert a floating-point value to fixed-point representation."""
    scaling_factor = 1 << fraction_bits
    max_val = (1 << (total_bits - 1)) - 1
    min_val = -(1 << (total_bits - 1))
    fixed_val = int(round(value * scaling_factor))
    return max(min(fixed_val, max_val), min_val) & ((1 << total_bits) - 1)


def pack_data(
    i,
    stepX,
    stepY,
    rayDirX,
    rayDirY,
    deltaDistX,
    deltaDistY,
    posX,
    posY,
    sideDistX,
    sideDistY,
):
    """Pack the data fields into a single value for `dda_fsm_in_tdata`."""
    packed_data = (
        (i & 0x1FF) << 130  # 9-bit i
        | (stepX & 0x1) << 129  # 1-bit stepX
        | (stepY & 0x1) << 128  # 1-bit stepY
        | (rayDirX & 0xFFFF) << 112  # 16-bit rayDirX
        | (rayDirY & 0xFFFF) << 96  # 16-bit rayDirY
        | (deltaDistX & 0xFFFF) << 80  # 16-bit deltaDistX
        | (deltaDistY & 0xFFFF) << 64  # 16-bit deltaDistY
        | (posX & 0xFFFF) << 48  # 16-bit posX
        | (posY & 0xFFFF) << 32  # 16-bit posY
        | (sideDistX & 0xFFFF) << 16  # 16-bit sideDistX
        | (sideDistY & 0xFFFF)  # 16-bit sideDistY
    )
    return packed_data


def cast_ray(
    mapX,
    mapY,
    deltaDistX,
    deltaDistY,
    sideDistX,
    sideDistY,
    stepX,
    stepY,
    screen_height,
):
    # Perform DDA
    curr_mapX = mapX
    curr_mapY = mapY
    curr_sideDistX = sideDistX
    curr_sideDistY = sideDistY
    hit = 0
    side = -1
    while hit == 0:
        # Jump to the next map square in the ray's path
        if curr_sideDistX < curr_sideDistY:
            curr_sideDistX += deltaDistX
            curr_mapX += stepX
            side = 0
        else:
            curr_sideDistY += deltaDistY
            curr_mapY += stepY
            side = 1

        # Check if the ray has hit a wall
        if (curr_mapX == 0) or (curr_mapY == 0) or (curr_mapX == 23) or (curr_mapY == 23): # if worldMap[mapX][mapY] > 0:
            hit = 1

    # Calculate perpendicular wall distance
    if side == 0:
        perpWallDist = curr_sideDistX - deltaDistX
    else:
        perpWallDist = curr_sideDistY - deltaDistY

    # Calculate line height based on screen height and wall distance
    if perpWallDist > 0:
        lineHeight = int(screen_height / perpWallDist)
    else:
        lineHeight = screen_height  # Fallback for edge cases

    return lineHeight, side


@cocotb.test()
async def test_a(dut):
    """cocotb test for dda"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.pixel_clk_in, 1, units="ns").start())

    dut.rst_in.value = 1
    #dut.dda_fsm_in_tvalid.value = 1  # FIFO has valid data for the receiver to consume
    dut.dda_fsm_out_tready.value = 1  # FIFO is ready to accept data from the sender
    await ClockCycles(dut.pixel_clk_in, 5)
    dut.rst_in.value = 0

    for posX in [11.5]:  # [11.5, 12.5, 20.5]:
        for posY in [11.5]:  # [11.5, 12.5, 20.5]:

            # Apply test inputs
            for i in range(screen_width):
                # Calculate cameraX for the current pixel
                cameraX = 2 * i / screen_width - 1

                # Calculate ray direction
                rayDirX = dirX + planeX * cameraX
                rayDirY = dirY + planeY * cameraX

                # Calculate deltaDist
                deltaDistX = 1e30 if rayDirX == 0 else abs(1 / rayDirX)
                deltaDistY = 1e30 if rayDirY == 0 else abs(1 / rayDirY)

                # Determine the current map position
                mapX = int(posX)
                mapY = int(posY)

                # Calculate steps and initial side distances
                if rayDirX < 0:
                    stepX = 0  # Representing -1 as 0 in 1-bit
                    stepX_true = -1
                    sideDistX = (posX - mapX) * deltaDistX
                else:
                    stepX = 1
                    stepX_true = 1
                    sideDistX = (mapX + 1.0 - posX) * deltaDistX

                if rayDirY < 0:
                    stepY = 0  # Representing -1 as 0 in 1-bit
                    stepY_true = -1
                    sideDistY = (posY - mapY) * deltaDistY
                else:
                    stepY = 1
                    stepY_true = 1
                    sideDistY = (mapY + 1.0 - posY) * deltaDistY

                # Convert to fixed-point representation
                rayDirX_fixed = to_fixed(rayDirX)
                rayDirY_fixed = to_fixed(rayDirY)
                deltaDistX_fixed = to_fixed(deltaDistX)
                deltaDistY_fixed = to_fixed(deltaDistY)
                posX_fixed = to_fixed(posX)
                posY_fixed = to_fixed(posY)
                sideDistX_fixed = to_fixed(sideDistX)
                sideDistY_fixed = to_fixed(sideDistY)

                # Pack data
                dda_input_data = pack_data(
                    i,
                    stepX,
                    stepY,
                    rayDirX_fixed,
                    rayDirY_fixed,
                    deltaDistX_fixed,
                    deltaDistY_fixed,
                    posX_fixed,
                    posY_fixed,
                    sideDistX_fixed,
                    sideDistY_fixed,
                )

                # Apply data to DUT
                dut.dda_fsm_in_tdata.value = dda_input_data
                dut.dda_fsm_in_tvalid.value = 1
                dut.dda_fsm_out_tready.value = 1

                # Wait for one clock cycle
                await RisingEdge(dut.pixel_clk_in)

                # Wait for output to be valid
                while not dut.dda_fsm_out_tvalid.value:
                    await RisingEdge(dut.pixel_clk_in)

                # Read and log output data
                # output_data = dut.dda_fsm_out_tdata.value
                # dut._log.info(
                #     f"Input: {hex(dda_input_data)}, Ray: {i}, Output: {hex(output_data)}"
                # )

                output_data = int(dut.dda_fsm_out_tdata.value)

                # Extract individual fields
                hcount_ray_out = (output_data >> 29) & 0x1FF  # 9 bits
                lineHeight_out = (output_data >> 21) & 0xFF  # 8 bits
                wallType_out = (output_data >> 20) & 0x1  # 1 bit
                mapData_out = (output_data >> 16) & 0xF  # 4 bits
                wallX_out = output_data & 0xFFFF  # 16 bits

                lineHeight_true, side_tru = cast_ray(
                    mapX,
                    mapY,
                    deltaDistX,
                    deltaDistY,
                    sideDistX,
                    sideDistY,
                    stepX_true,
                    stepY_true,
                    180,
                )

                dut._log.info(
                    f"i: {i}, "
                    f"lineHeight_true={lineHeight_true}, "
                    f"wallType_true={side_tru}, "
                )

                # Log the output fields
                dut._log.info(
                    # f"i: {i}, "
                    # f"lineHeight_true={lineHeight_true}, "
                    # f"wallType_true={side_tru}, "
                    f"hcount_ray={hcount_ray_out}, "
                    f"lineHeight={lineHeight_out}, "
                    f"wallType={wallType_out}, "
                    f"mapData={mapData_out}, "
                    f"wallX={wallX_out}"
                )

                # Deassert valid signal
                #dut.dda_fsm_in_tvalid.value = 0


def is_runner():
    """DDA FSM Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [
        proj_path / "hdl" / "dda.sv",
        proj_path / "hdl" / "dda_fsm.sv",
        proj_path / "hdl" / "evt_counter.sv",
        proj_path / "hdl" / "divu.sv",
    ]
    sources += [proj_path / "hdl" / "xilinx_single_port_ram_read_first.v"]
    build_test_args = ["-Wall"]
    parameters = {"SCREEN_WIDTH": 320, "SCREEN_HEIGHT": 180, "N": 24}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="dda",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=("1ns", "1ps"),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="dda",
        test_module="test_dda_0",
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    is_runner()
