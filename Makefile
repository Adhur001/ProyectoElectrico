IVERILOG = iverilog
VVP      = vvp
FLAGS    = -g2012

RTL_ALU     = rtl/alu/alu.v rtl/alu/alu_array.v
RTL_REG     = rtl/vregfile/vregisters.v
RTL_PIPE    = rtl/pipeline/issue.v rtl/pipeline/execute.v rtl/pipeline/writeback.v
RTL_TOP     = rtl/ve_top.v
RTL_ALL     = $(RTL_ALU) $(RTL_REG) $(RTL_PIPE) $(RTL_TOP)
RTL_LSU     = rtl/LSU/vlsu.v

.PHONY: all tb_alu tb_vregfile tb_ve_top tb_vlsu_decoder tb_vlsu_integration clean

all: tb_alu tb_vregfile tb_ve_top tb_vlsu_decoder tb_vlsu_integration

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

tb_vlsu_decoder:
	$(IVERILOG) $(FLAGS) -o sim_vlsu $(RTL_LSU) testbench/tb_vlsu_decoder.v
	$(VVP) sim_vlsu
	echo "Waveform: gtkwave tb_vlsu.vcd"

tb_vlsu_integration:
	$(IVERILOG) $(FLAGS) -o sim_vlsu_integration $(RTL_LSU) $(RTL_REG) testbench/tb_vlsu_integration.v
	$(VVP) sim_vlsu_integration
	@echo "Waveform: gtkwave tb_vlsu_integration.vcd"

clean:
	rm -f sim_alu sim_vregisters sim_ve_top sim_vlsu sim_vlsu_integration *.vcd
