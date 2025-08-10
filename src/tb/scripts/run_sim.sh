#!/bin/bash
# run_sim.sh - compile and run the fifo testbench with iverilog + vvp
set -e

mkdir -p sim

iverilog -g2012 -o sim/fifo_tb.vvp src/fifo.v tb/fifo_tb.v
vvp sim/fifo_tb.vvp | tee sim/simulation_log.txt

echo "Waveform: sim/fifo_tb.vcd"
echo "Log: sim/simulation_log.txt"
