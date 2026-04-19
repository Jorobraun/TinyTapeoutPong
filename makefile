.PHONY: all
all: sim

SIM = icarus
TOPLEVEL_LANG = verilog

# Alle deine Verilog-Dateien
VERILOG_SOURCES += $(PWD)/src/main.sv

# Ihm sagen wo ich die Datein finde
COMPILE_ARGS += -I$(PWD)/src

# Top-Level Modulname (muss mit dem in deiner .v-Datei übereinstimmen)
TOPLEVEL = main

# Python-Testbench (ohne .py)
COCOTB_TEST_MODULES = test.test

include $(shell cocotb-config --makefiles)/Makefile.sim

wave:
	gtkwave wave.vcd &