module tb_axi_lite_gpio;
`include "tb_common.vh"

    reg  [7:0] gpio_in = 8'h00;
    wire [7:0] gpio_out, gpio_oe;

    axi_lite_gpio #(.GPIO_W(8)) dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(M_AWADDR), .S_AWVALID(M_AWVALID), .S_AWREADY(M_AWREADY),
        .S_WDATA(M_WDATA), .S_WSTRB(M_WSTRB), .S_WVALID(M_WVALID), .S_WREADY(M_WREADY),
        .S_BRESP(M_BRESP), .S_BVALID(M_BVALID), .S_BREADY(M_BREADY),
        .S_ARADDR(M_ARADDR), .S_ARVALID(M_ARVALID), .S_ARREADY(M_ARREADY),
        .S_RDATA(M_RDATA), .S_RRESP(M_RRESP), .S_RVALID(M_RVALID), .S_RREADY(M_RREADY),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe)
    );

    initial begin
        $dumpfile("axi_lite_gpio.vcd");
        $dumpvars(0, tb_axi_lite_gpio);
        reset_dut;

        // 1. direction register
        do_write(32'h0000_0000, 32'h0000_000F, 4'hF);
        expect_eq("DIR write resp OKAY   ", got_resp, 2'b00);
        do_read (32'h0000_0000);
        expect_eq("DIR read back         ", got_data, 32'h0000_000F);
        expect_eq("gpio_oe pins          ", gpio_oe, 8'h0F);

        // 2. output register
        do_write(32'h0000_0004, 32'h0000_00A5, 4'hF);
        do_read (32'h0000_0004);
        expect_eq("OUT read back         ", got_data, 32'h0000_00A5);
        expect_eq("gpio_out pins         ", gpio_out, 8'hA5);

        // 3. input register (synchronised, so allow a few clocks)
        gpio_in = 8'h3C;
        wait_clks(4);
        do_read (32'h0000_0008);
        expect_eq("IN reads pin value    ", got_data, 32'h0000_003C);
        gpio_in = 8'hC3;
        wait_clks(4);
        do_read (32'h0000_0008);
        expect_eq("IN follows pins       ", got_data, 32'h0000_00C3);

        // 4. error responses
        do_write(32'h0000_0008, 32'hFF, 4'hF);
        expect_eq("write to IN -> SLVERR ", got_resp, 2'b10);
        do_read (32'h0000_000C);
        expect_eq("reserved read SLVERR  ", got_resp, 2'b10);
        do_read (32'h0000_0020);
        expect_eq("bad offset read SLVERR", got_resp, 2'b10);

        summary;
        $finish;
    end
endmodule
