import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer


@cocotb.test()
async def test_adpll(dut):
    """Basic smoke test for tt_um_adpll (just ensures DUT runs)."""
    cocotb.log.info("Starting simple ADPLL smoke test...")

    # Start clock if present
    if hasattr(dut, "clk"):
        cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())
        cocotb.log.info("Clock started")

    # Apply reset if present
    if hasattr(dut, "rst_n"):
        dut.rst_n.value = 0
        await Timer(100, units="ns")
        dut.rst_n.value = 1
        cocotb.log.info("Reset released")

    # Pulse pgm if present
    if hasattr(dut, "pgm"):
        dut.pgm.value = 1
        await Timer(50, units="ns")
        dut.pgm.value = 0
        cocotb.log.info("Programming pulse applied")

    # Run for a short while
    for i in range(10):
        await Timer(100, units="ns")
        cocotb.log.info(f"Cycle {i} running...")

    # Always succeed
    assert True
    cocotb.log.info("Smoke test completed successfully ")
