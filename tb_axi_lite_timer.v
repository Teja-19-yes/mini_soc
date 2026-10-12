module tb_axi_lite_timer;
`include "tb_common.vh"

    wire timer_irq;

    axi_lite_timer dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(M_AWADDR), .S_AWVALID(M_AWVALID), .S_AWREADY(M_AWREADY),
        .S_WDATA(M_WDATA), .S_WSTRB(M_WSTRB), .S_WVALID(M_WVALID), .S_WREADY(M_WREADY),
        .S_BRESP(M_BRESP), .S_BVALID(M_BVALID), .S_BREADY(M_BREADY),
        .S_ARADDR(M_ARADDR), .S_ARVALID(M_ARVALID), .S_ARREADY(M_ARREADY),
        .S_RDATA(M_RDATA), .S_RRESP(M_RRESP), .S_RVALID(M_RVALID), .S_RREADY(M_RREADY),
        .timer_irq(timer_irq)
    );

    initial begin
        $dumpfile("axi_lite_timer.vcd");
        $dumpvars(0, tb_axi_lite_timer);
        reset_dut;

        // 1. one-shot: COMPARE = 10, EN = 1
        do_write(32'h0000_0004, 32'd10, 4'hF);
        do_read (32'h0000_0004);
        expect_eq("COMPARE read back     ", got_data, 32'd10);
        do_write(32'h0000_0000, 32'h0000_0001, 4'hF);
        wait_clks(40);
        do_read (32'h0000_000C);
        expect_eq("one-shot MATCH set    ", got_data, 32'h1);
        do_read (32'h0000_0000);
        expect_eq("one-shot EN self-clear", got_data, 32'h0);
        expect_eq("no irq (IRQ_EN = 0)   ", timer_irq, 1'b0);

        // 2. clear MATCH (write 1 to clear)
        do_write(32'h0000_000C, 32'h1, 4'hF);
        do_read (32'h0000_000C);
        expect_eq("MATCH write-1-clear   ", got_data, 32'h0);

        // 3. auto-reload with interrupt: EN | AUTO_RELOAD | IRQ_EN
        do_write(32'h0000_0004, 32'd5, 4'hF);
        do_write(32'h0000_0000, 32'h0000_0007, 4'hF);
        wait (timer_irq);
        expect_eq("irq raised on match   ", timer_irq, 1'b1);
        do_read (32'h0000_0000);
        expect_eq("auto-reload keeps EN  ", got_data, 32'h7);

        // 4. stop timer, clear flag, irq must drop
        do_write(32'h0000_0000, 32'h0, 4'hF);
        do_write(32'h0000_000C, 32'h1, 4'hF);
        do_read (32'h0000_000C);
        expect_eq("MATCH cleared again   ", got_data, 32'h0);
        expect_eq("irq dropped           ", timer_irq, 1'b0);

        // 5. COUNT runs while enabled
        do_write(32'h0000_0004, 32'd1000, 4'hF);
        do_write(32'h0000_0000, 32'h1, 4'hF);
        wait_clks(50);
        do_read (32'h0000_0008);
        expect_eq("COUNT is running      ", (got_data > 0) && (got_data < 1000), 1'b1);
        do_write(32'h0000_0000, 32'h0, 4'hF);
        wait_clks(2);
        do_read (32'h0000_0008);
        expect_eq("COUNT held at 0 if off", got_data, 32'h0);

        // 6. error responses
        do_write(32'h0000_0008, 32'h5, 4'hF);
        expect_eq("write to COUNT SLVERR ", got_resp, 2'b10);
        do_read (32'h0000_0040);
        expect_eq("bad offset read SLVERR", got_resp, 2'b10);

        summary;
        $finish;
    end
endmodule
