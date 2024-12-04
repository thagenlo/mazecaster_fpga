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

    # TEST 1 ADD (Q8.8): 25+.3125 - WORKS
    # dut.arg1.value = 0x1900 #25
    # dut.arg2.value = 0x0050 #0.3125
    # #value should be 1950

    # TEST 2 ADD (Q8.8): -5+-.25 - WORKS
    # dut.arg1.value = 0xfb00 #-5
    # dut.arg2.value = 0xffc0 #-.25
    # value should be FACO

    # TEST 3 ADD (Q8.8): 122 + 50.25 - WORKS
    # dut.arg1.value = 0x7a00 #122
    # dut.arg2.value = 0x3240 #50.25



    # TEST 1 ADD (Q12.12): 0.000244140625 + 0.00048828125 - WORKS (REGULAR)
    dut.arg1.value = 0x000001 #.000244140625
    dut.arg2.value = 0x000002 #0.00048828125
    # #value should be 0.000732421875 (000003)

    # TEST 2 ADD (Q12.12): -5+-.625 - WORKS (SIGNED)
    # dut.arg1.value = 0xfff600 #-.625
    # dut.arg2.value = 0xffb000 #-5
    # value should be ffa600

    # TEST 3 ADD (Q12.12): 122 + 50.25 - WORKS (OVERFLOW)
    # dut.arg1.value = 0x7a00 #122
    # dut.arg2.value = 0x3240 #50.25



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
    sources = [proj_path / "hdl" / 'fp' / 'add.sv']
    build_test_args = ["-Wall"]
    parameters = {'WIDTH': 24, 'FRAC_WIDTH': 12}
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel="add",
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale = ('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel="add",
        test_module="test_fp_add",
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    arithmetic_runner()