SIM=iverilog
VVP=vvp

SRC=.
TEST=.


all: compile view



compile: 
	iverilog $(SRC)/counter.v $(TEST)/tb.v -o sim.vvp


sim: compile
	$(VVP) sim.vvp 

view: sim
	gtkwave sim.vcd


clean:
	rm *.vvp *.vcd 
