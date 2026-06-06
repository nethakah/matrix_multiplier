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
    print(f"After reset - k={dut.dp.k.value} i={dut.dp.i.value} j={dut.dp.j.value}")

    # debug
    print(f"After reset - ops_rdy = {dut.ops_rdy.value}")
    await RisingEdge(dut.clk)
    print(f"One cycle later - ops_rdy = {dut.ops_rdy.value}")

    n = 4
    width = 8
    matA = generateMatrix(n, width)
    matB = generateMatrix(n, width)

    # test code
    
    # inputs are valid
    dut.ops_val.value=1

    # wait for hardware to be ready
    timeout=100
    cycles=0
    while not dut.ops_rdy.value:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > timeout:
            raise Exception("timeout waiting for ops_rdy")
        # breaks when ops_rdy (hardware is ready to accept)

    # send matrices in
    await streamMatrixIn(dut, matA)
    await streamMatrixIn(dut, matB)
    
    # wait for control to leave IDLE (ops_rdy goes low)
    while dut.ops_rdy.value:
        await RisingEdge(dut.clk)

    # deassert ops_val
    dut.ops_val.value = 0

    # debug — check state after loading
    await RisingEdge(dut.clk)
    print(f"After streaming - loaded = {dut.loaded.value}")
    print(f"After streaming - s_axis_tready = {dut.s_axis_tready.value}")
    print(f"After streaming - ops_rdy = {dut.ops_rdy.value}")
    print(f"After streaming - load_cnt = {dut.dp.load_cnt.value}")
    
    # read results as they stream out
    softwareResult = matrixMultiplier(matA, matB)
    hardwareResult = await readHardwareResult(dut, n)

    assert softwareResult == hardwareResult, f"Error. Hardware: {hardwareResult}, Software: {softwareResult}"


async def streamMatrixIn(dut, mat: list):
    rows = len(mat)
    cols = len(mat[0])

    for row in range(rows):
        for col in range(cols):
            dut.s_axis_tdata.value = mat[row][col]
            dut.s_axis_tvalid.value = 1
            dut.s_axis_tlast.value = (row==rows-1 and col==cols-1)

            cycles = 0
            while True:
                await RisingEdge(dut.clk)
                cycles += 1
                if cycles > 100:
                    raise Exception(f"Timeout waiting for s_axis_tready at row={row} col={col}")
                if dut.s_axis_tready.value:
                    break
            

            dut.s_axis_tvalid.value = 0
            dut.s_axis_tlast.value = 0


async def readHardwareResult(dut, n):
    flatResult = []
    dut.m_axis_tready.value = 1

    cycles = 0
    while True:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 1000:
            raise Exception(f"Timeout waiting for m_axis_tvalid after {cycles} cycles")
        if dut.m_axis_tvalid.value and dut.m_axis_tready.value:
            flatResult.append(int(dut.m_axis_tdata.value))
            if dut.m_axis_tlast.value:
                break
    
    dut.m_axis_tready.value = 0
    return [ flatResult[r*n:(r+1)*n] for r in range(n)]

 