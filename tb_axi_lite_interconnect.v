module tb_axi_lite_interconnect;
`include "tb_common.vh"

    // interconnect <-> slaves
    wire [31:0] S_AWADDR, S_WDATA, S_ARADDR;
    wire [3:0]  S_WSTRB;
    wire [2:0]  S_AWVALID, S_AWREADY, S_WVALID, S_WREADY, S_BVALID, S_BREADY;
    wire [2:0]  S_ARVALID, S_ARREADY, S_RVALID, S_RREADY;
    wire [5:0]  S_BRESP, S_RRESP;
    wire [95:0] S_RDATA;

    axi_lite_interconnect dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .M_AWADDR(M_AWADDR), .M_AWVALID(M_AWVALID), .M_AWREADY(M_AWREADY),
        .M_WDATA(M_WDATA), .M_WSTRB(M_WSTRB), .M_WVALID(M_WVALID), .M_WREADY(M_WREADY),
        .M_BRESP(M_BRESP), .M_BVALID(M_BVALID), .M_BREADY(M_BREADY),
        .M_ARADDR(M_ARADDR), .M_ARVALID(M_ARVALID), .M_ARREADY(M_ARREADY),
        .M_RDATA(M_RDATA), .M_RRESP(M_RRESP), .M_RVALID(M_RVALID), .M_RREADY(M_RREADY),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID), .S_AWREADY(S_AWREADY),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID), .S_WREADY(S_WREADY),
        .S_BRESP(S_BRESP), .S_BVALID(S_BVALID), .S_BREADY(S_BREADY),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID), .S_ARREADY(S_ARREADY),
        .S_RDATA(S_RDATA), .S_RRESP(S_RRESP), .S_RVALID(S_RVALID), .S_RREADY(S_RREADY)
    );

    axi_lite_mem_slave #(.INIT_TAG(32'hA000_0000)) slave0 (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID[0]), .S_AWREADY(S_AWREADY[0]),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID[0]), .S_WREADY(S_WREADY[0]),
        .S_BRESP(S_BRESP[1:0]), .S_BVALID(S_BVALID[0]), .S_BREADY(S_BREADY[0]),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID[0]), .S_ARREADY(S_ARREADY[0]),
        .S_RDATA(S_RDATA[31:0]), .S_RRESP(S_RRESP[1:0]), .S_RVALID(S_RVALID[0]), .S_RREADY(S_RREADY[0])
    );
    axi_lite_mem_slave #(.INIT_TAG(32'hB000_0000)) slave1 (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID[1]), .S_AWREADY(S_AWREADY[1]),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID[1]), .S_WREADY(S_WREADY[1]),
        .S_BRESP(S_BRESP[3:2]), .S_BVALID(S_BVALID[1]), .S_BREADY(S_BREADY[1]),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID[1]), .S_ARREADY(S_ARREADY[1]),
        .S_RDATA(S_RDATA[63:32]), .S_RRESP(S_RRESP[3:2]), .S_RVALID(S_RVALID[1]), .S_RREADY(S_RREADY[1])
    );
    axi_lite_mem_slave #(.INIT_TAG(32'hC000_0000)) slave2 (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID[2]), .S_AWREADY(S_AWREADY[2]),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID[2]), .S_WREADY(S_WREADY[2]),
        .S_BRESP(S_BRESP[5:4]), .S_BVALID(S_BVALID[2]), .S_BREADY(S_BREADY[2]),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID[2]), .S_ARREADY(S_ARREADY[2]),
        .S_RDATA(S_RDATA[95:64]), .S_RRESP(S_RRESP[5:4]), .S_RVALID(S_RVALID[2]), .S_RREADY(S_RREADY[2])
    );

    initial begin
        $dumpfile("axi_lite_interconnect.vcd");
        $dumpvars(0, tb_axi_lite_interconnect);
        reset_dut;

        // 1. each address range reaches the right slave
        do_read(32'h4000_0000); expect_eq("route to slave 0       ", got_data, 32'hA000_0000);
        do_read(32'h4001_0004); expect_eq("route to slave 1       ", got_data, 32'hB000_0001);
        do_read(32'h4002_0008); expect_eq("route to slave 2       ", got_data, 32'hC000_0002);

        // 2. writes land only in the selected slave
        do_write(32'h4001_0000, 32'h1234_5678, 4'hF);
        expect_eq("write to slave 1 OKAY  ", got_resp, 2'b00);
        do_read (32'h4001_0000); expect_eq("slave 1 read back      ", got_data, 32'h1234_5678);
        do_read (32'h4000_0000); expect_eq("slave 0 untouched      ", got_data, 32'hA000_0000);
        do_read (32'h4002_0000); expect_eq("slave 2 untouched      ", got_data, 32'hC000_0000);

        do_write(32'h4002_000C, 32'hCAFE_F00D, 4'hF);
        do_read (32'h4002_000C); expect_eq("slave 2 read back      ", got_data, 32'hCAFE_F00D);
        do_write(32'h4000_0008, 32'hDEAD_BEEF, 4'hF);
        do_read (32'h4000_0008); expect_eq("slave 0 read back      ", got_data, 32'hDEAD_BEEF);

        // 3. unmapped addresses are answered with DECERR by the interconnect
        do_read (32'h5000_0000);
        expect_eq("read unmapped DECERR   ", got_resp, 2'b11);
        do_write(32'h5000_0000, 32'h1, 4'hF);
        expect_eq("write unmapped DECERR  ", got_resp, 2'b11);
        do_read (32'h4003_0000);
        expect_eq("just past slave 2      ", got_resp, 2'b11);

        // 4. slave-generated error passes through (mapped, offset out of range)
        do_read (32'h4000_0100);
        expect_eq("slave SLVERR on read   ", got_resp, 2'b10);
        do_write(32'h4001_0100, 32'h1, 4'hF);
        expect_eq("slave SLVERR on write  ", got_resp, 2'b10);

        // 5. bus still works after errors
        do_read (32'h4001_0000); expect_eq("works after errors     ", got_data, 32'h1234_5678);

        summary;
        $finish;
    end
endmodule
