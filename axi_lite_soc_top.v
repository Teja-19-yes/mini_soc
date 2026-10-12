module axi_lite_soc_top #(
    parameter GPIO_W = 8
)(
    input  wire              ACLK,
    input  wire              ARESETN,

    // command interface of the AXI4-Lite master
    input  wire              start,
    input  wire              rw,
    input  wire [31:0]       addr,
    input  wire [31:0]       wdata,
    input  wire [3:0]        wstrb,
    output wire              busy,
    output wire              done,
    output wire [31:0]       rdata,
    output wire [1:0]        resp,

    // peripheral pins
    input  wire [GPIO_W-1:0] gpio_in,
    output wire [GPIO_W-1:0] gpio_out,
    output wire [GPIO_W-1:0] gpio_oe,
    output wire              timer_irq,
    output wire [31:0]       reg_ctrl_out,
    output wire [31:0]       reg_data_out
);

    // ---------------- master <-> interconnect ----------------
    wire [31:0] M_AWADDR;  wire [2:0] M_AWPROT;  wire M_AWVALID;  wire M_AWREADY;
    wire [31:0] M_WDATA;   wire [3:0] M_WSTRB;   wire M_WVALID;   wire M_WREADY;
    wire [1:0]  M_BRESP;   wire       M_BVALID;  wire M_BREADY;
    wire [31:0] M_ARADDR;  wire [2:0] M_ARPROT;  wire M_ARVALID;  wire M_ARREADY;
    wire [31:0] M_RDATA;   wire [1:0] M_RRESP;   wire M_RVALID;   wire M_RREADY;

    axi_lite_master master (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .start(start), .rw(rw), .addr(addr), .wdata(wdata), .wstrb(wstrb),
        .busy(busy), .done(done), .rdata(rdata), .resp(resp),
        .M_AWADDR(M_AWADDR), .M_AWPROT(M_AWPROT), .M_AWVALID(M_AWVALID), .M_AWREADY(M_AWREADY),
        .M_WDATA(M_WDATA),   .M_WSTRB(M_WSTRB),   .M_WVALID(M_WVALID),   .M_WREADY(M_WREADY),
        .M_BRESP(M_BRESP),   .M_BVALID(M_BVALID), .M_BREADY(M_BREADY),
        .M_ARADDR(M_ARADDR), .M_ARPROT(M_ARPROT), .M_ARVALID(M_ARVALID), .M_ARREADY(M_ARREADY),
        .M_RDATA(M_RDATA),   .M_RRESP(M_RRESP),   .M_RVALID(M_RVALID),   .M_RREADY(M_RREADY)
    );

    // ---------------- interconnect <-> slaves ----------------
    wire [31:0] S_AWADDR, S_WDATA, S_ARADDR;
    wire [3:0]  S_WSTRB;
    wire [2:0]  S_AWVALID, S_AWREADY, S_WVALID, S_WREADY, S_BVALID, S_BREADY;
    wire [2:0]  S_ARVALID, S_ARREADY, S_RVALID, S_RREADY;
    wire [5:0]  S_BRESP, S_RRESP;
    wire [95:0] S_RDATA;

    axi_lite_interconnect interconnect (
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

    // ---------------- slave 0 : register bank ----------------
    reg irq_d;
    always @(posedge ACLK) begin
        if (!ARESETN) irq_d <= 1'b0;
        else          irq_d <= timer_irq;
    end
    wire [31:0] status_set = {31'h0, timer_irq & ~irq_d};   // timer irq rising edge

    axi_lite_regs regs (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID[0]), .S_AWREADY(S_AWREADY[0]),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID[0]), .S_WREADY(S_WREADY[0]),
        .S_BRESP(S_BRESP[1:0]), .S_BVALID(S_BVALID[0]), .S_BREADY(S_BREADY[0]),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID[0]), .S_ARREADY(S_ARREADY[0]),
        .S_RDATA(S_RDATA[31:0]), .S_RRESP(S_RRESP[1:0]), .S_RVALID(S_RVALID[0]), .S_RREADY(S_RREADY[0]),
        .ctrl_out(reg_ctrl_out), .data_out(reg_data_out), .status_set(status_set)
    );

    // ---------------- slave 1 : GPIO ----------------
    axi_lite_gpio #(.GPIO_W(GPIO_W)) gpio (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID[1]), .S_AWREADY(S_AWREADY[1]),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID[1]), .S_WREADY(S_WREADY[1]),
        .S_BRESP(S_BRESP[3:2]), .S_BVALID(S_BVALID[1]), .S_BREADY(S_BREADY[1]),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID[1]), .S_ARREADY(S_ARREADY[1]),
        .S_RDATA(S_RDATA[63:32]), .S_RRESP(S_RRESP[3:2]), .S_RVALID(S_RVALID[1]), .S_RREADY(S_RREADY[1]),
        .gpio_in(gpio_in), .gpio_out(gpio_out), .gpio_oe(gpio_oe)
    );

    // ---------------- slave 2 : timer ----------------
    axi_lite_timer timer (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .S_AWADDR(S_AWADDR), .S_AWVALID(S_AWVALID[2]), .S_AWREADY(S_AWREADY[2]),
        .S_WDATA(S_WDATA), .S_WSTRB(S_WSTRB), .S_WVALID(S_WVALID[2]), .S_WREADY(S_WREADY[2]),
        .S_BRESP(S_BRESP[5:4]), .S_BVALID(S_BVALID[2]), .S_BREADY(S_BREADY[2]),
        .S_ARADDR(S_ARADDR), .S_ARVALID(S_ARVALID[2]), .S_ARREADY(S_ARREADY[2]),
        .S_RDATA(S_RDATA[95:64]), .S_RRESP(S_RRESP[5:4]), .S_RVALID(S_RVALID[2]), .S_RREADY(S_RREADY[2]),
        .timer_irq(timer_irq)
    );

endmodule
