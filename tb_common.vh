// -----------------------------------------------------------------------------
// tb_common.vh : shared testbench scaffold.  `include it INSIDE a testbench
// module.  Provides clock/reset, the AXI4-Lite master (axi_lite_master) driving
// wires M_*, user-side tasks (do_write / do_read) and PASS/FAIL helpers.
// Define NO_MASTER before including if the DUT already contains the master.
// -----------------------------------------------------------------------------
reg ACLK    = 1'b0;
reg ARESETN = 1'b0;
always #5 ACLK = ~ACLK;                    // 100 MHz

// user-side command interface of the master
reg         start = 1'b0;
reg         rw    = 1'b0;
reg  [31:0] addr  = 32'h0;
reg  [31:0] wdata = 32'h0;
reg  [3:0]  wstrb = 4'hF;
wire        busy;
wire        done;
wire [31:0] rdata;
wire [1:0]  resp;

`ifndef NO_MASTER
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
`endif

integer    pass_cnt = 0;
integer    fail_cnt = 0;
reg [31:0] got_data = 32'h0;
reg [1:0]  got_resp = 2'b00;

task reset_dut;
begin
    ARESETN = 1'b0;
    repeat (4) @(posedge ACLK);
    ARESETN = 1'b1;
    repeat (2) @(posedge ACLK);
end
endtask

task wait_clks(input integer n);
begin
    repeat (n) @(posedge ACLK);
end
endtask

task do_write(input [31:0] a, input [31:0] d, input [3:0] s);
begin
    @(posedge ACLK); #1;
    start = 1'b1; rw = 1'b1; addr = a; wdata = d; wstrb = s;
    @(posedge ACLK); #1;
    start = 1'b0;
    wait (done);
    got_resp = resp;
end
endtask

task do_read(input [31:0] a);
begin
    @(posedge ACLK); #1;
    start = 1'b1; rw = 1'b0; addr = a;
    @(posedge ACLK); #1;
    start = 1'b0;
    wait (done);
    got_data = rdata;
    got_resp = resp;
end
endtask

task expect_eq(input [255:0] name, input [31:0] got, input [31:0] exp);
begin
    if (got === exp) begin
        $display("PASS  %0s  (%h)", name, got);
        pass_cnt = pass_cnt + 1;
    end else begin
        $display("FAIL  %0s  got %h, expected %h", name, got, exp);
        fail_cnt = fail_cnt + 1;
    end
end
endtask

task summary;
begin
    $display("--------------------------------------------");
    $display("Tests passed: %0d   Tests failed: %0d", pass_cnt, fail_cnt);
    $display("--------------------------------------------");
end
endtask

// watchdog
initial begin
    #5000000;
    $display("TIMEOUT - a transaction never completed");
    $finish;
end

