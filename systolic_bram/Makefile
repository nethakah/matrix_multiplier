SIM = icarus
TOPLEVEL_LANG = verilog
VERILOG_SOURCES = $(PWD)/datapath.sv $(PWD)/control.sv $(PWD)/chip.sv $(PWD)/array.sv $(PWD)/pe.sv $(PWD)/bram.sv
TOPLEVEL = chip
MODULE = testbench

# matrix dims: A is MxN, B is NxK, C is MxK
M ?= 4
N ?= 4
K ?= 4

# push params into the RTL (icarus) and the testbench (env)
COMPILE_ARGS += -Pchip.M=$(M) -Pchip.N=$(N) -Pchip.K=$(K)
export M
export N
export K

include $(shell cocotb-config --makefiles)/Makefile.sim