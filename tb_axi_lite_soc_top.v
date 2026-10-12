module tb_axi_lite_soc_top;
`define NO_MASTER
`include "tb_common.vh"

    reg  [7:0] gpio_in = 8'h00;
    wire [7:0] gpio_out, gpio_oe;
    wire       timer_irq;
    wire [31:0] reg_ctrl_out, reg_data_out;

    axi_lite_soc_top #(.GPIO_W(8)) dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .start(start), .rw(rw), .addr(addr), .wdata(wdata), .wstrb(wstrb),
        .busy(busy), .done(done), .rdata(rdata), .resp(resp),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe),
        .timer_irq(timer_irq), .reg_ctrl_out(reg_ctrl_out), .reg_data_out(reg_data_out)
    );

    // memory map
    localparam REGS  = 32'h4000_0000;
    localparam GPIO  = 32'h4001_0000;
    localparam TIMER = 32'h4002_0000;

    initial begin
        $dumpfile("axi_lite_soc_top.vcd");
        $dumpvars(0, tb_axi_lite_soc_top);
        reset_dut;

        // ---- register bank ----
        do_read (REGS + 32'h0C);
        expect_eq("regs: ID value         ", got_data, 32'h4158_4C31);
        do_write(REGS + 32'h00, 32'hCAFE_0001, 4'hF);
        do_read (REGS + 32'h00);
        expect_eq("regs: CTRL read back   ", got_data, 32'hCAFE_0001);
        expect_eq("regs: ctrl_out pins    ", reg_ctrl_out, 32'hCAFE_0001);

        // ---- GPIO ----
        do_write(GPIO + 32'h00, 32'h0000_00FF, 4'hF);
        do_write(GPIO + 32'h04, 32'h0000_005A, 4'hF);
        expect_eq("gpio: output pins      ", gpio_out, 8'h5A);
        expect_eq("gpio: output enable    ", gpio_oe, 8'hFF);
        gpio_in = 8'h81;
        wait_clks(4);
        do_read (GPIO + 32'h08);
        expect_eq("gpio: input read       ", got_data, 32'h0000_0081);

        // ---- timer + interrupt captured in regs STATUS ----
        do_write(TIMER + 32'h04, 32'd8, 4'hF);                 // COMPARE
        do_write(TIMER + 32'h00, 32'h0000_0007, 4'hF);         // EN | AUTO | IRQ_EN
        wait (timer_irq);
        expect_eq("timer: irq raised      ", timer_irq, 1'b1);
        wait_clks(2);
        do_read (REGS + 32'h04);
        expect_eq("regs: STATUS bit0 set  ", got_data[0], 1'b1);
        do_write(REGS + 32'h04, 32'h1, 4'hF);                  // clear it
        do_read (REGS + 32'h04);
        expect_eq("regs: STATUS cleared   ", got_data[0], 1'b0);
        do_write(TIMER + 32'h00, 32'h0, 4'hF);                 // stop timer
        do_write(TIMER + 32'h0C, 32'h1, 4'hF);                 // clear MATCH
        do_read (TIMER + 32'h0C);
        expect_eq("timer: MATCH cleared   ", got_data, 32'h0);
        expect_eq("timer: irq dropped     ", timer_irq, 1'b0);

        // ---- error cases ----
        do_read (32'h5000_0000);
        expect_eq("unmapped -> DECERR     ", got_resp, 2'b11);
        do_write(REGS + 32'h0C, 32'h0, 4'hF);
        expect_eq("write RO -> SLVERR     ", got_resp, 2'b10);

        summary;
        $finish;
    end
endmodule
