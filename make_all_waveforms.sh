#!/bin/bash
plot() {
    vcd=$1; out=$2; title=$3; shift 3
    if [ ! -f "$vcd" ]; then echo "SKIP (no $vcd): $out"; return; fi
    mkdir -p "$(dirname "$out")"
    python3 waveform_tools/plot_vcd.py "$vcd" --title "$title" -o "$out" "$@" || echo "FAILED: $out"
}

V=axi_lite_soc_top.vcd; D=waveforms/system
plot $V $D/01_full_run.png "Full system simulation" -s ACLK ARESETN start rw addr wdata done resp gpio_out timer_irq
plot $V $D/02_write_transaction.png "System: AXI4-Lite write" -s ACLK state M_AWADDR M_AWVALID M_AWREADY M_WDATA M_WVALID M_WREADY M_BVALID M_BREADY M_BRESP --around M_AWVALID --span 150
plot $V $D/03_read_transaction.png "System: AXI4-Lite read" -s ACLK state M_ARADDR M_ARVALID M_ARREADY M_RVALID M_RREADY M_RDATA M_RRESP --around M_ARVALID --span 150
plot $V $D/04_routing_to_gpio.png "System: write routed to GPIO" -s ACLK M_AWADDR M_AWVALID S_AWVALID S_AWREADY S_WVALID S_BVALID M_BVALID --around M_AWADDR=0x40010000 --lead 30 --span 150
plot $V $D/05_gpio_output.png "System: GPIO output" -s ACLK rw addr wdata done gpio_oe gpio_out --around gpio_out=0x5A --lead 120 --span 260
plot $V $D/06_timer_irq_to_status.png "System: timer interrupt into STATUS" -s ACLK count match timer_irq status_set status --around timer_irq --lead 100 --span 250
plot $V $D/07_decerr_unmapped_read.png "System: DECERR for unmapped address" -s ACLK M_ARADDR M_ARVALID M_ARREADY M_RVALID M_RREADY M_RRESP --around M_RRESP=3 --lead 80 --span 130
plot $V $D/08_slverr_write_to_ro.png "System: SLVERR on write to read-only register" -s ACLK M_AWADDR M_AWVALID S_AWVALID M_BVALID M_BRESP --around M_BRESP=2 --lead 80 --span 150

V=axi_lite_master.vcd; D=waveforms/master
plot $V $D/01_full_run.png "Master: full simulation" -s ACLK start rw addr wdata done rdata resp
plot $V $D/02_write.png "Master: write and FSM state" -s ACLK start rw addr busy state M_AWVALID M_AWREADY M_WVALID M_WREADY M_BVALID M_BREADY done resp --around start --lead 20 --span 130
plot $V $D/03_read.png "Master: read and FSM state" -s ACLK start rw addr busy state M_ARVALID M_ARREADY M_RVALID M_RREADY rdata done resp --around M_ARVALID --lead 40 --span 130
plot $V $D/04_error_response.png "Master: SLVERR response" -s ACLK start addr state M_BVALID M_BRESP done resp --around resp=2 --lead 100 --span 150

V=axi_lite_regs.vcd; D=waveforms/regs
plot $V $D/01_full_run.png "Register bank: full simulation" -s ACLK addr rw wdata done rdata resp ctrl_out data_out
plot $V $D/02_write_ctrl.png "Register bank: write CTRL" -s ACLK M_AWADDR M_AWVALID M_AWREADY M_WVALID M_WREADY M_BVALID M_BRESP ctrl_out --around M_AWVALID --span 150
plot $V $D/03_read_id.png "Register bank: read ID" -s ACLK M_ARADDR M_ARVALID M_ARREADY M_RVALID M_RDATA M_RRESP --around M_ARVALID --span 120
plot $V $D/04_status_write1_clear.png "Register bank: STATUS write-1-to-clear" -s ACLK status_set status M_AWADDR M_WDATA M_BVALID --around status_set=5 --lead 20 --span 350
plot $V $D/05_slverr_write_to_ro.png "Register bank: SLVERR on write to ID" -s ACLK M_AWADDR M_AWVALID M_BVALID M_BRESP --around M_BRESP=2 --lead 80 --span 130

V=axi_lite_gpio.vcd; D=waveforms/gpio
plot $V $D/01_full_run.png "GPIO: full simulation" -s ACLK addr rw wdata done rdata resp gpio_in gpio_oe gpio_out
plot $V $D/02_write_dir_out.png "GPIO: DIR and OUT writes" -s ACLK M_AWADDR M_AWVALID M_WDATA M_BVALID gpio_oe gpio_out --around M_AWVALID --lead 20 --span 300
plot $V $D/03_input_synchroniser.png "GPIO: input synchroniser" -s ACLK gpio_in in_s1 in_s2 M_ARADDR M_ARVALID M_RVALID M_RDATA --around gpio_in=0x3C --lead 10 --span 200
plot $V $D/04_slverr_write_to_ro.png "GPIO: SLVERR on write to IN" -s ACLK M_AWADDR M_AWVALID M_BVALID M_BRESP --around M_BRESP=2 --lead 80 --span 130

V=axi_lite_timer.vcd; D=waveforms/timer
plot $V $D/01_full_run.png "Timer: full simulation" -s ACLK ctrl count match timer_irq
plot $V $D/02_write_compare.png "Timer: write COMPARE" -s ACLK M_AWADDR M_AWVALID M_AWREADY M_WVALID M_BVALID M_BRESP compare ctrl --around M_AWVALID --span 160
plot $V $D/03_one_shot.png "Timer: one-shot" -s ACLK ctrl compare count match --around match=1 --lead 150 --span 250
plot $V $D/04_auto_reload_irq.png "Timer: auto-reload with interrupt" -s ACLK ctrl compare count match timer_irq --around timer_irq --lead 80 --span 200

V=axi_lite_interconnect.vcd; D=waveforms/interconnect
plot $V $D/01_full_run.png "Interconnect: full simulation" -s ACLK M_AWADDR M_ARADDR M_AWVALID M_ARVALID S_AWVALID S_ARVALID M_BRESP M_RRESP
plot $V $D/02_read_routing.png "Interconnect: read routed to slave 1" -s ACLK rstate M_ARADDR M_ARVALID S_ARVALID S_RVALID M_RVALID M_RDATA --around M_ARADDR=0x40010004 --lead 30 --span 130
plot $V $D/03_write_routing.png "Interconnect: write routed to slave 1" -s ACLK wstate M_AWADDR M_AWVALID S_AWVALID S_WVALID S_BVALID M_BVALID M_BRESP --around M_AWADDR=0x40010000 --lead 30 --span 150
plot $V $D/04_decerr_unmapped_write.png "Interconnect: DECERR for unmapped write" -s ACLK M_AWADDR M_AWVALID S_AWVALID M_WVALID S_WVALID M_BVALID M_BRESP --around M_BRESP=3 --lead 100 --span 150
plot $V $D/05_slverr_passthrough.png "Interconnect: slave SLVERR passed through" -s ACLK M_AWADDR M_AWVALID S_BRESP M_BVALID M_BRESP --around M_BRESP=2 --lead 100 --span 150

echo "Done. Images are in the waveforms/ folder"
