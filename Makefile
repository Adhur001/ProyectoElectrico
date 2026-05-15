IVERILOG = iverilog
VVP      = vvp
FLAGS    = -g2012

RTL_ALU     = rtl/alu/alu.v rtl/alu/alu_array.v
RTL_REG     = rtl/vregfile/vregisters.v
RTL_PIPE    = rtl/pipeline/issue.v rtl/pipeline/execute.v rtl/pipeline/writeback.v
RTL_TOP     = rtl/ve_top.v
RTL_ALL     = $(RTL_ALU) $(RTL_REG) $(RTL_PIPE) $(RTL_TOP)

.PHONY: all tb_alu tb_vregfile tb_ve_top clean

all: tb_alu tb_vregfile tb_ve_top

tb_alu:
	$(IVERILOG) $(FLAGS) -o sim_alu $(RTL_ALU) testbench/tb_alu.v
	$(VVP) sim_alu
	@echo "Waveform: gtkwave tb_alu.vcd"

tb_vregfile:
	$(IVERILOG) $(FLAGS) -o sim_vregisters $(RTL_REG) testbench/tb_vregfile.v
	$(VVP) sim_vregisters
	@echo "Waveform: gtkwave tb_vregisters.vcd"

tb_ve_top:
	$(IVERILOG) $(FLAGS) -o sim_ve_top $(RTL_ALL) testbench/tb_ve_top.v
	$(VVP) sim_ve_top
	@echo "Waveform: gtkwave tb_ve_top.vcd"

clean:
	rm -f sim_alu sim_vregisters sim_ve_top *.vcd
