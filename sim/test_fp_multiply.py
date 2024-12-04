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
    """cocotb test for fp arithmetic"""
    dut._log.info("Starting...")
    cocotb.start_soon(Clock(dut.clk_in, 10, units="ns").start())
    dut._log.info("Holding reset...")
    # reseting
    dut.rst_in.value = 1

    # TEST 1 MULTIPLY (Q8.8): 25 * 0.3125 - 
    # dut.arg1.value = 0x1900  # 25.0
    # dut.arg2.value = 0x0050  # 0.3125
    # Expected value: 0x04C8 (12.5 in Q8.8)

    # TEST 2 MULTIPLY (Q8.8): -5 * -0.25 - 
    # dut.arg1.value = 0xFB00  # -5.0
    # dut.arg2.value = 0xFFC0  # -0.25
    # Expected value: 0x0140 (1.25 in Q8.8)

    # TEST 3 MULTIPLY (Q8.8): 122 * 50.25 (OVER FLOW)- 
    # dut.arg1.value = 0x7A00  # 122.0
    # dut.arg2.value = 0x3240  # 50.25
    # Expected value: 0x7FFF (Clipped to max in Q8.8)



    # TEST 1 MULTIPLY (Q12.12): 0.000244140625 * 0.00048828125 - WORKS
    # dut.arg1.value = 0x000001  # 0.000244140625
    # dut.arg2.value = 0x000002  # 0.00048828125
    # Expected value: 0x000000 (0.00000011920928955078125, effectively zero in Q12.12)


    # TEST 2 MULTIPLY (Q12.12): -5.0 * -0.625 - WORKS
    # dut.arg1.value = 0xFFF600  # -5.0
    # dut.arg2.value = 0xFFD000  # -0.625
    # Expected value: 0x0037C0 (3.125 in Q12.12)

    # TEST 3 MULTIPLY (Q12.12): 122.0 * 50.25 - OVERFLOW
    dut.arg1.value = 0x07A000  # 122.0
    dut.arg2.value = 0x032400  # 50.25
    # Expected value: 0x7FFFFF (Clipped to max in Q12.12)



    # TEST 1 ADD (Q16.16): 0.000244140625 + 0.00048828125 - WORKS (REGULAR)
    # dut.arg1.value = 0x000001 #.000244140625
    # dut.arg2.value = 0x000002 #0.00048828125
    # #value should be 0.000732421875 (000003)

    # TEST 2 ADD (Q16.16): -5+-.625 - WORKS (SIGNED)
    # dut.arg1.value = 0xfff600 #-.625
    # dut.arg2.value = 0xffb000 #-5
    # value should be ffa600

    # TEST 3 ADD (Q16.16): 122 + 50.25 - WORKS (OVERFLOW)
    # dut.arg1.value = 0x7a00 #122
    # dut.arg2.value = 0x3240 #50.25


    



    



    await ClockCycles(dut.clk_in, 10)





def arithmetic_runner():
    """Python runner."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / 'fp' / 'multiply.sv']
    build_test_args = ["-Wall"]
    parameters = {'WIDTH': 24, 'FRAC_WIDTH': 12}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="multiply",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="multiply",
        test_module="test_fp_multiply",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    arithmetic_runner()