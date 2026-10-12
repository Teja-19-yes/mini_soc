module tb_axi_lite_regs;
`include "tb_common.vh"
 
    wire [31:0] ctrl_out, data_out;
    reg  [31:0] status_set = 32'h0;
 
    axi_lite_regs dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(M_AWADDR), .S_AWVALID(M_AWVALID), .S_AWREADY(M_AWREADY),
        .S_WDATA(M_WDATA), .S_WSTRB(M_WSTRB), .S_WVALID(M_WVALID), .S_WREADY(M_WREADY),
        .S_BRESP(M_BRESP), .S_BVALID(M_BVALID), .S_BREADY(M_BREADY),
        .S_ARADDR(M_ARADDR), .S_ARVALID(M_ARVALID), .S_ARREADY(M_ARREADY),
        .S_RDATA(M_RDATA), .S_RRESP(M_RRESP), .S_RVALID(M_RVALID), .S_RREADY(M_RREADY),
        .ctrl_out(ctrl_out), .data_out(data_out), .status_set(status_set)
    );
 
    initial begin
        $dumpfile("axi_lite_regs.vcd");
        $dumpvars(0, tb_axi_lite_regs);
        reset_dut;
 
        // 1. read-only ID register
        do_read(32'h0000_000C);
        expect_eq("ID register value     ", got_data, 32'h4158_4C31);
        expect_eq("ID read resp OKAY     ", got_resp, 2'b00);
 
        // 2. CTRL read/write
        do_write(32'h0000_0000, 32'hA5A5_A5A5, 4'hF);
        expect_eq("CTRL write resp OKAY  ", got_resp, 2'b00);
        do_read (32'h0000_0000);
        expect_eq("CTRL read back        ", got_data, 32'hA5A5_A5A5);
        expect_eq("ctrl_out pins         ", ctrl_out, 32'hA5A5_A5A5);
 
        // 3. byte strobe: only the lowest byte changes
        do_write(32'h0000_0000, 32'h1111_11FF, 4'b0001);
        do_read (32'h0000_0000);
        expect_eq("CTRL byte strobe      ", got_data, 32'hA5A5_A5FF);
 
        // 4. DATA register
        do_write(32'h0000_0008, 32'h1234_5678, 4'hF);
        do_read (32'h0000_0008);
        expect_eq("DATA read back        ", got_data, 32'h1234_5678);
        expect_eq("data_out pins         ", data_out, 32'h1234_5678);
 
        // 5. STATUS: hardware sets bits 0 and 2, software clears bit 0
        @(posedge ACLK); #1 status_set = 32'h0000_0005;
        @(posedge ACLK); #1 status_set = 32'h0;
        do_read (32'h0000_0004);
        expect_eq("STATUS set by HW      ", got_data, 32'h0000_0005);
        do_write(32'h0000_0004, 32'h0000_0001, 4'hF);
        do_read (32'h0000_0004);
        expect_eq("STATUS write-1-clear  ", got_data, 32'h0000_0004);
        do_write(32'h0000_0004, 32'h0000_0000, 4'hF);          // writing 0 changes nothing
        do_read (32'h0000_0004);
        expect_eq("STATUS write-0 no-op  ", got_data, 32'h0000_0004);
 
        // 6. error responses
        do_write(32'h0000_000C, 32'hFFFF_FFFF, 4'hF);
        expect_eq("write to RO -> SLVERR ", got_resp, 2'b10);
        do_read (32'h0000_0010);
        expect_eq("read bad offset SLVERR", got_resp, 2'b10);
        do_write(32'h0000_0010, 32'h1, 4'hF);
        expect_eq("write bad offset SLVERR", got_resp, 2'b10);
 
        summary;
        $finish;
    end
endmodule
 
