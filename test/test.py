import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_adpll(dut):
    """Testbench for TinyTapeout ADPLL module (tt_um_adpll)."""
    cocotb.log.info("Starting ADPLL test...")

    # Start reference clock
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # Reset
    dut.rst_n.value = 0
    dut.pgm.value = 0
    await Timer(100, units="ns")
    dut.rst_n.value = 1
    await Timer(100, units="ns")

    # Program the loop parameters (dummy example)
    cocotb.log.info("Programming loop parameters...")
    dut.pgm.value = 1
    await Timer(100, units="ns")
    dut.pgm.value = 0

    # Run simulation and monitor outputs
    cocotb.log.info("Running ADPLL...")
    fb_seen = []
    dco_seen = []

    for cycle in range(50):
        await RisingEdge(dut.clk)
        fb_seen.append(int(dut.fb_clk.value))
        dco_seen.append(int(dut.dco_out.value))
        cocotb.log.info(f"Cycle {cycle}: fb_clk={fb_seen[-1]} dco_out={dco_seen[-1]}")

    # Assertions
    assert any(fb_seen[i] != fb_seen[i-1] for i in range(1, len(fb_seen))), "fb_clk never toggled!"
    assert any(dco_seen[i] != dco_seen[i-1] for i in range(1, len(dco_seen))), "dco_out never toggled!"
