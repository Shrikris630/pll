# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


@cocotb.test()
async def test_adpll(dut):
    """Testbench for TinyTapeout ADPLL module (tt_um_adpll)"""

    dut._log.info("Starting ADPLL test...")

    # Start clock (20 ns period = 50 MHz)
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # Reset and initialize inputs
    dut.rst.value = 1
    dut.clr.value = 0
    dut.pgm.value = 0
    dut.out_sel.value = 0
    dut.param_sel.value = 0
    dut.pgm_value.value = 0
    await ClockCycles(dut.clk, 10)

    dut.rst.value = 0
    dut.clr.value = 1
    await ClockCycles(dut.clk, 2)
    dut.clr.value = 0

    dut._log.info("Programming loop parameters...")

    # Program Ndiv
    dut.pgm.value = 1
    dut.param_sel.value = 0
    dut.pgm_value.value = 0
    await ClockCycles(dut.clk, 1)

    # Program alpha
    dut.param_sel.value = 1
    dut.pgm_value.value = 2
    await ClockCycles(dut.clk, 1)

    # Program beta
    dut.param_sel.value = 2
    dut.pgm_value.value = 3
    await ClockCycles(dut.clk, 1)

    # Program DCO offset
    dut.param_sel.value = 3
    dut.pgm_value.value = 8
    await ClockCycles(dut.clk, 1)

    # Program DCO threshold
    dut.param_sel.value = 4
    dut.pgm_value.value = 12
    await ClockCycles(dut.clk, 1)

    # Program kdco
    dut.param_sel.value = 5
    dut.pgm_value.value = 1
    await ClockCycles(dut.clk, 1)

    dut.pgm.value = 0

    dut._log.info("Running ADPLL...")

    # Observe feedback clock over some cycles
    for i in range(50):
        await RisingEdge(dut.clk)
        dut._log.info(f"Cycle {i}: fb_clk={dut.fb_clk.value} dco_out={dut.dco_out.value}")

    # Example check: fb_clk should toggle at least once
    fb_seen = [int(dut.fb_clk.value)]
    for _ in range(200):
        await RisingEdge(dut.clk)
        fb_seen.append(int(dut.fb_clk.value))

    assert any(fb_seen[i] != fb_seen[i - 1] for i in range(1, len(fb_seen))), "fb_clk never toggled!"
    dut._log.info("ADPLL test passed")

    # Keep testing the module by changing the input values, waiting for
    # one or more clock cycles, and asserting the expected output values.
