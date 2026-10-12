#!/bin/bash
# Compile and run every testbench with Icarus Verilog.  Usage: bash run_all.sh
set -e
run() {  # run <name> <files...>
    name=$1; shift
    echo "=== $name ==="
    iverilog -o sim_$name "$@"
    vvp sim_$name | grep -E "PASS|FAIL|Tests|TIMEOUT"
}
run master axi_lite_master.v tb_axi_lite_master.v
run regs  axi_lite_master.v axi_lite_regs.v  tb_axi_lite_regs.v
run gpio  axi_lite_master.v axi_lite_gpio.v  tb_axi_lite_gpio.v
run timer axi_lite_master.v axi_lite_timer.v tb_axi_lite_timer.v
run ic    axi_lite_master.v axi_lite_interconnect.v axi_lite_mem_slave.v tb_axi_lite_interconnect.v
run soc   axi_lite_master.v axi_lite_interconnect.v axi_lite_regs.v axi_lite_gpio.v \
          axi_lite_timer.v axi_lite_soc_top.v tb_axi_lite_soc_top.v
