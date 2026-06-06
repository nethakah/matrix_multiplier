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
    
    # deassert ops_val
    dut.ops_val.value = 0
    # debug — check state after loading
    await RisingEdge(dut.clk)
    print(f"After streaming - loaded = {dut.loaded.value}")
    print(f"After streaming - s_axis_tready = {dut.s_axis_tready.value}")
    print(f"After streaming - ops_rdy = {dut.ops_rdy.value}")
    print(f"After streaming - load_cnt = {dut.dp.load_cnt.value}")
    
    # wait for hardware to compute
    while not dut.res_val.value:
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles % 1000 == 0:
            print(f"Cycle {cycles} - res_val={dut.res_val.value} ops_rdy={dut.ops_rdy.value}")
        if cycles > 10000:
            raise Exception(f"Timeout waiting for res_val after {cycles} cycles")

    # tell hardware we're ready for results
    dut.res_rdy.value = 1

    # gather all results
    softwareResult = matrixMultiplier(matA, matB)
    hardwareResult = await readHardwareResult(dut, n, width)

    # deassert res_rdy
    dut.res_rdy.value = 0

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


async def readHardwareResult(dut, n, width):
    resultMat = [ [0 for _ in range(n)] for _ in range(n) ]
    for i in range(n):
        for j in range(n):

            dut.m_axis_tready.value=1

            while not dut.m_axis_tvalid.value:
                await RisingEdge(dut.clk)
            
            await RisingEdge(dut.clk) # need to wait for transfer to occur
            resultMat[i][j] = dut.m_axis_tdata.value

            dut.m_axis_tready.value = 0 # deassert
    
    return resultMat



