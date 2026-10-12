module axi_lite_slave_model (
    input  wire        ACLK,
    input  wire        ARESETN,
    input  wire [31:0] AWADDR,
    input  wire        AWVALID,
    output reg         AWREADY,
    input  wire [31:0] WDATA,
    input  wire [3:0]  WSTRB,
    input  wire        WVALID,
    output reg         WREADY,
    output reg  [1:0]  BRESP,
    output reg         BVALID,
    input  wire        BREADY,
    input  wire [31:0] ARADDR,
    input  wire        ARVALID,
    output reg         ARREADY,
    output reg  [31:0] RDATA,
    output reg  [1:0]  RRESP,
    output reg         RVALID,
    input  wire        RREADY
);
    reg [31:0] mem [0:3];
    reg [31:0] aw_l, w_l, ar_l;
    reg [3:0]  ws_l;
    reg        aw_got, w_got, ar_got;
    integer    i;
 
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            AWREADY <= 0; WREADY <= 0; BVALID <= 0; BRESP <= 0;
            ARREADY <= 0; RVALID <= 0; RDATA <= 0; RRESP <= 0;
            aw_got <= 0; w_got <= 0; ar_got <= 0;
            for (i = 0; i < 4; i = i + 1) mem[i] <= 32'h0;
        end else begin
            // ---------- write address / write data capture ----------
            if (AWVALID && !aw_got && !BVALID && !AWREADY) begin
                AWREADY <= 1; aw_l <= AWADDR; aw_got <= 1;
            end else AWREADY <= 0;
 
            if (WVALID && !w_got && !BVALID && !WREADY) begin
                WREADY <= 1; w_l <= WDATA; ws_l <= WSTRB; w_got <= 1;
            end else WREADY <= 0;
 
            // ---------- perform write, issue response ----------
            if (aw_got && w_got) begin
                if (aw_l < 32'h10) begin
                    if (ws_l[0]) mem[aw_l[3:2]][7:0]   <= w_l[7:0];
                    if (ws_l[1]) mem[aw_l[3:2]][15:8]  <= w_l[15:8];
                    if (ws_l[2]) mem[aw_l[3:2]][23:16] <= w_l[23:16];
                    if (ws_l[3]) mem[aw_l[3:2]][31:24] <= w_l[31:24];
                    BRESP <= 2'b00;
                end else BRESP <= 2'b10;      // SLVERR
                BVALID <= 1; aw_got <= 0; w_got <= 0;
            end
            if (BVALID && BREADY) BVALID <= 0;
 
            // ---------- read ----------
            if (ARVALID && !ar_got && !RVALID && !ARREADY) begin
                ARREADY <= 1; ar_l <= ARADDR; ar_got <= 1;
            end else ARREADY <= 0;
 
            if (ar_got) begin
                if (ar_l < 32'h10) begin RDATA <= mem[ar_l[3:2]]; RRESP <= 2'b00; end
                else               begin RDATA <= 32'hDEAD_DEAD;  RRESP <= 2'b10; end
                RVALID <= 1; ar_got <= 0;
            end
            if (RVALID && RREADY) RVALID <= 0;
        end
    end
endmodule
 
 
module tb_axi_lite_master;
 
    reg ACLK = 0, ARESETN = 0;
    always #5 ACLK = ~ACLK;                 // 100 MHz
 
    // user side
    reg         start = 0, rw = 0;
    reg  [31:0] addr = 0, wdata = 0;
    reg  [3:0]  wstrb = 4'hF;
    wire        busy, done;
    wire [31:0] rdata;
    wire [1:0]  resp;
 
    // AXI wires
    wire [31:0] AWADDR, WDATA, ARADDR, RDATA;
    wire [2:0]  AWPROT, ARPROT;
    wire [3:0]  WSTRB;
    wire [1:0]  BRESP, RRESP;
    wire AWVALID, AWREADY, WVALID, WREADY, BVALID, BREADY;
    wire ARVALID, ARREADY, RVALID, RREADY;
 
    axi_lite_master dut (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .start(start), .rw(rw), .addr(addr), .wdata(wdata), .wstrb(wstrb),
        .busy(busy), .done(done), .rdata(rdata), .resp(resp),
        .M_AWADDR(AWADDR), .M_AWPROT(AWPROT), .M_AWVALID(AWVALID), .M_AWREADY(AWREADY),
        .M_WDATA(WDATA),   .M_WSTRB(WSTRB),   .M_WVALID(WVALID),   .M_WREADY(WREADY),
        .M_BRESP(BRESP),   .M_BVALID(BVALID), .M_BREADY(BREADY),
        .M_ARADDR(ARADDR), .M_ARPROT(ARPROT), .M_ARVALID(ARVALID), .M_ARREADY(ARREADY),
        .M_RDATA(RDATA),   .M_RRESP(RRESP),   .M_RVALID(RVALID),   .M_RREADY(RREADY)
    );
 
    axi_lite_slave_model slave (
        .ACLK(ACLK), .ARESETN(ARESETN),
        .AWADDR(AWADDR), .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WVALID(WVALID), .WREADY(WREADY),
        .BRESP(BRESP), .BVALID(BVALID), .BREADY(BREADY),
        .ARADDR(ARADDR), .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RDATA(RDATA), .RRESP(RRESP), .RVALID(RVALID), .RREADY(RREADY)
    );
 
    integer pass_cnt = 0, fail_cnt = 0;
    reg [31:0] got_data;
    reg [1:0]  got_resp;
 
    // ---------------- user-side tasks ----------------
    task do_write(input [31:0] a, input [31:0] d, input [3:0] s);
    begin
        @(posedge ACLK); #1;
        start = 1; rw = 1; addr = a; wdata = d; wstrb = s;
        @(posedge ACLK); #1;
        start = 0;
        wait (done);
        got_resp = resp;
    end
    endtask
 
    task do_read(input [31:0] a);
    begin
        @(posedge ACLK); #1;
        start = 1; rw = 0; addr = a;
        @(posedge ACLK); #1;
        start = 0;
        wait (done);
        got_data = rdata;
        got_resp = resp;
    end
    endtask
 
    task check(input [255:0] name, input [31:0] exp_d, input [1:0] exp_r);
    begin
        if (got_data === exp_d && got_resp === exp_r) begin
            $display("PASS  %0s  data=%h resp=%b", name, got_data, got_resp);
            pass_cnt = pass_cnt + 1;
        end else begin
            $display("FAIL  %0s  data=%h (exp %h) resp=%b (exp %b)",
                     name, got_data, exp_d, got_resp, exp_r);
            fail_cnt = fail_cnt + 1;
        end
    end
    endtask
 
    // ---------------- stimulus ----------------
    initial begin
        $dumpfile("axi_lite_master.vcd");
        $dumpvars(0, tb_axi_lite_master);
 
        repeat (4) @(posedge ACLK);
        ARESETN = 1;
        repeat (2) @(posedge ACLK);
 
        // 1. write then read back
        do_write(32'h0000_0000, 32'hDEAD_BEEF, 4'hF);
        got_data = 32'h0; check("write resp OKAY   ", 32'h0, 2'b00);
        do_read (32'h0000_0000);
        check("read back word 0   ", 32'hDEAD_BEEF, 2'b00);
 
        // 2. other locations (back-to-back transactions)
        do_write(32'h0000_0004, 32'h1234_5678, 4'hF);
        do_write(32'h0000_0008, 32'hCAFE_F00D, 4'hF);
        do_write(32'h0000_000C, 32'hA5A5_A5A5, 4'hF);
        do_read (32'h0000_0004); check("read back word 1   ", 32'h1234_5678, 2'b00);
        do_read (32'h0000_0008); check("read back word 2   ", 32'hCAFE_F00D, 2'b00);
        do_read (32'h0000_000C); check("read back word 3   ", 32'hA5A5_A5A5, 2'b00);
 
        // 3. byte strobes: only the lowest byte should change
        do_write(32'h0000_0000, 32'h0000_00AA, 4'b0001);
        do_read (32'h0000_0000);
        check("byte strobe write  ", 32'hDEAD_BEAA, 2'b00);
 
        // 4. error responses (unmapped address -> SLVERR in this model)
        do_write(32'h0000_0100, 32'h1111_1111, 4'hF);
        got_data = 32'h0; check("write bad address  ", 32'h0, 2'b10);
        do_read (32'h0000_0100);
        check("read bad address   ", 32'hDEAD_DEAD, 2'b10);
 
        $display("--------------------------------------------");
        $display("Tests passed: %0d   Tests failed: %0d", pass_cnt, fail_cnt);
        $display("--------------------------------------------");
        $finish;
    end
 
    // watchdog
    initial begin
        #100000;
        $display("TIMEOUT - transaction never completed");
        $finish;
    end
 
endmodule
 

