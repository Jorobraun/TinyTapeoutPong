#!/bin/bash

#chmod +x setup.sh
#./setup.sh

echo "Startet"
iverilog -o output.out *.v
vvp output.out
gtkwave wave.vcd
echo "Beendet"