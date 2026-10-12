#!/bin/bash
# Generate report-ready waveform PNGs from the full-system VCD.
# Run after:  bash run_all.sh      (this creates axi_lite_soc_top.vcd)
# Needs: python3 + matplotlib (pip install matplotlib)
set -e
VCD=axi_lite_soc_top.vcd
PLOT="python3 waveform_tools/plot_vcd.py $VCD"
mkdir -p waveforms

# 1. write transaction (window starts at the first AWVALID)
$PLOT -s ACLK M_AWADDR M_AWVALID M_AWREADY M_WDATA M_WVALID M_WREADY M_BVALID M_BREADY M_BRESP \
      --around M_AWVALID --span 150 --title "AXI4-Lite write transaction" -o waveforms/write.png

# 2. read transaction (window starts at the first ARVALID)
$PLOT -s ACLK M_ARADDR M_ARVALID M_ARREADY M_RVALID M_RREADY M_RDATA M_RRESP \
      --around M_ARVALID --span 150 --title "AXI4-Lite read transaction" -o waveforms/read.png

# 3. DECERR response from the interconnect (read of unmapped address 0x5000_0000)
$PLOT -s ACLK M_ARADDR M_ARVALID M_ARREADY M_RVALID M_RREADY M_RRESP \
      --around M_RRESP=3 --lead 80 --span 130 --title "Unmapped address: DECERR response" -o waveforms/decerr.png

# 4. timer interrupt
$PLOT -s ACLK timer_irq --around timer_irq --span 400 \
      --title "Timer interrupt" -o waveforms/timer_irq.png

echo "Images saved in the waveforms/ folder"
