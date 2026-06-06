import cocotb 
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from golden_model import matrixMultiplier, generateMatrix

@cocotb.test()
async def testMatrixMultiplier(dut): # async so we can wait for clock edge to happen
    # clock start
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # activate reset
    dut.rst.value = 1
    await RisingEdge(dut.clk) # pause til rising edge

    # release reset
    dut.rst.value = 0
    await RisingEdge(dut.clk) # pause til rising edge


async def streamMatrixIn(dut, mat: list):
    rows = len(mat)
    cols = len(mat[0])

    for row in range(rows):
        for col in range(cols):
            dut.s_axis_tdata.value = mat[row][col]
            dut.s_axis_tvalid.value = 1
            dut.s_axis_tlast.value = (row==rows-1 and col==cols-1)

            while True:
                await RisingEdge(dut.clk)
                if dut.s_axis_tready.value:
                    break

    dut.s_axis_tvalid.value = 0
    dut.s_axis_tlast.value = 0

            
