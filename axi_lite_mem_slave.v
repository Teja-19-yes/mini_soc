module axi_lite_mem_slave #(
    parameter ADDR_W = 32,
    parameter [31:0] INIT_TAG = 32'h0
)(
    input  wire              ACLK,
    input  wire              ARESETN,
    input  wire [ADDR_W-1:0] S_AWADDR,
    input  wire              S_AWVALID,
    output wire              S_AWREADY,
    input  wire [31:0]       S_WDATA,
    input  wire [3:0]        S_WSTRB,
    input  wire              S_WVALID,
    output wire              S_WREADY,
    output reg  [1:0]        S_BRESP,
    output reg               S_BVALID,
    input  wire              S_BREADY,
    input  wire [ADDR_W-1:0] S_ARADDR,
    input  wire              S_ARVALID,
    output wire              S_ARREADY,
    output reg  [31:0]       S_RDATA,
    output reg  [1:0]        S_RRESP,
    output reg               S_RVALID,
    input  wire              S_RREADY
);
    reg [31:0] mem [0:3];
    reg              aw_got, w_got;
    reg [ADDR_W-1:0] aw_l;
    reg [31:0]       w_l;
    reg [3:0]        ws_l;
    integer          i;

    assign S_AWREADY = ~aw_got & ~S_BVALID;
    assign S_WREADY  = ~w_got  & ~S_BVALID;
    assign S_ARREADY = ~S_RVALID;

    wire do_write = aw_got & w_got & ~S_BVALID;
    wire wr_ok    = (aw_l[15:4]     == 12'h000);
    wire rd_ok    = (S_ARADDR[15:4] == 12'h000);

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            aw_got <= 1'b0;  w_got <= 1'b0;  aw_l <= {ADDR_W{1'b0}};  w_l <= 32'h0;  ws_l <= 4'h0;
            S_BVALID <= 1'b0;  S_BRESP <= 2'b00;
            S_RVALID <= 1'b0;  S_RDATA <= 32'h0;  S_RRESP <= 2'b00;
            for (i = 0; i < 4; i = i + 1) mem[i] <= INIT_TAG + i;
        end else begin
            if (S_AWVALID && S_AWREADY) begin aw_l <= S_AWADDR; aw_got <= 1'b1; end
            if (S_WVALID  && S_WREADY)  begin w_l <= S_WDATA; ws_l <= S_WSTRB; w_got <= 1'b1; end

            if (do_write) begin
                aw_got <= 1'b0;  w_got <= 1'b0;  S_BVALID <= 1'b1;
                if (wr_ok) begin
                    S_BRESP <= 2'b00;
                    if (ws_l[0]) mem[aw_l[3:2]][7:0]   <= w_l[7:0];
                    if (ws_l[1]) mem[aw_l[3:2]][15:8]  <= w_l[15:8];
                    if (ws_l[2]) mem[aw_l[3:2]][23:16] <= w_l[23:16];
                    if (ws_l[3]) mem[aw_l[3:2]][31:24] <= w_l[31:24];
                end else S_BRESP <= 2'b10;
            end
            if (S_BVALID && S_BREADY) S_BVALID <= 1'b0;

            if (S_ARVALID && S_ARREADY) begin
                S_RVALID <= 1'b1;
                if (rd_ok) begin S_RDATA <= mem[S_ARADDR[3:2]]; S_RRESP <= 2'b00; end
                else       begin S_RDATA <= 32'h0;              S_RRESP <= 2'b10; end
            end
            if (S_RVALID && S_RREADY) S_RVALID <= 1'b0;
        end
    end
endmodule
