module axi_lite_interconnect #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32,
    parameter [31:0] BASE0 = 32'h4000_0000,
    parameter [31:0] BASE1 = 32'h4001_0000,
    parameter [31:0] BASE2 = 32'h4002_0000
)(
    input  wire                 ACLK,
    input  wire                 ARESETN,

    // ---------------- master side ----------------
    input  wire [ADDR_W-1:0]    M_AWADDR,
    input  wire                 M_AWVALID,
    output reg                  M_AWREADY,
    input  wire [DATA_W-1:0]    M_WDATA,
    input  wire [DATA_W/8-1:0]  M_WSTRB,
    input  wire                 M_WVALID,
    output reg                  M_WREADY,
    output reg  [1:0]           M_BRESP,
    output reg                  M_BVALID,
    input  wire                 M_BREADY,
    input  wire [ADDR_W-1:0]    M_ARADDR,
    input  wire                 M_ARVALID,
    output reg                  M_ARREADY,
    output reg  [DATA_W-1:0]    M_RDATA,
    output reg  [1:0]           M_RRESP,
    output reg                  M_RVALID,
    input  wire                 M_RREADY,

    // ---------------- slave side (3 slaves) ----------------
    output wire [ADDR_W-1:0]    S_AWADDR,
    output reg  [2:0]           S_AWVALID,
    input  wire [2:0]           S_AWREADY,
    output wire [DATA_W-1:0]    S_WDATA,
    output wire [DATA_W/8-1:0]  S_WSTRB,
    output reg  [2:0]           S_WVALID,
    input  wire [2:0]           S_WREADY,
    input  wire [5:0]           S_BRESP,
    input  wire [2:0]           S_BVALID,
    output reg  [2:0]           S_BREADY,
    output wire [ADDR_W-1:0]    S_ARADDR,
    output reg  [2:0]           S_ARVALID,
    input  wire [2:0]           S_ARREADY,
    input  wire [3*DATA_W-1:0]  S_RDATA,
    input  wire [5:0]           S_RRESP,
    input  wire [2:0]           S_RVALID,
    output reg  [2:0]           S_RREADY
);

    // broadcast channels
    assign S_AWADDR = M_AWADDR;
    assign S_WDATA  = M_WDATA;
    assign S_WSTRB  = M_WSTRB;
    assign S_ARADDR = M_ARADDR;

    // ---------------- address decode ----------------
    wire [2:0] aw_hit = { M_AWADDR[31:16] == BASE2[31:16],
                          M_AWADDR[31:16] == BASE1[31:16],
                          M_AWADDR[31:16] == BASE0[31:16] };
    wire [2:0] ar_hit = { M_ARADDR[31:16] == BASE2[31:16],
                          M_ARADDR[31:16] == BASE1[31:16],
                          M_ARADDR[31:16] == BASE0[31:16] };
    wire aw_none = ~|aw_hit;
    wire ar_none = ~|ar_hit;
    wire [1:0] aw_idx = aw_hit[0] ? 2'd0 : (aw_hit[1] ? 2'd1 : 2'd2);
    wire [1:0] ar_idx = ar_hit[0] ? 2'd0 : (ar_hit[1] ? 2'd1 : 2'd2);

    // =========================== WRITE PATH ===========================
    localparam [1:0] W_IDLE = 2'd0, W_DATA = 2'd1, W_RESP = 2'd2;
    reg [1:0] wstate;
    reg [1:0] wr_sel;
    reg       wr_err;

    always @* begin
        S_AWVALID = 3'b000;  M_AWREADY = 1'b0;
        S_WVALID  = 3'b000;  M_WREADY  = 1'b0;
        S_BREADY  = 3'b000;  M_BVALID  = 1'b0;  M_BRESP = 2'b00;
        case (wstate)
            W_IDLE: begin
                S_AWVALID = aw_hit & {3{M_AWVALID}};
                M_AWREADY = M_AWVALID & (aw_none | (|(aw_hit & S_AWREADY)));
            end
            W_DATA: begin
                if (wr_err) M_WREADY = 1'b1;                 // swallow data
                else begin
                    S_WVALID[wr_sel] = M_WVALID;
                    M_WREADY         = S_WREADY[wr_sel];
                end
            end
            W_RESP: begin
                if (wr_err) begin
                    M_BVALID = 1'b1;
                    M_BRESP  = 2'b11;                        // DECERR
                end else begin
                    S_BREADY[wr_sel] = M_BREADY;
                    M_BVALID         = S_BVALID[wr_sel];
                    M_BRESP          = S_BRESP[2*wr_sel +: 2];
                end
            end
            default: ;
        endcase
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            wstate <= W_IDLE;  wr_sel <= 2'd0;  wr_err <= 1'b0;
        end else begin
            case (wstate)
                W_IDLE: if (M_AWVALID && M_AWREADY) begin
                            wr_err <= aw_none;
                            wr_sel <= aw_idx;
                            wstate <= W_DATA;
                        end
                W_DATA: if (M_WVALID && M_WREADY)  wstate <= W_RESP;
                W_RESP: if (M_BVALID && M_BREADY)  wstate <= W_IDLE;
                default: wstate <= W_IDLE;
            endcase
        end
    end

    // =========================== READ PATH ===========================
    localparam R_IDLE = 1'b0, R_DATA = 1'b1;
    reg       rstate;
    reg [1:0] rd_sel;
    reg       rd_err;

    always @* begin
        S_ARVALID = 3'b000;  M_ARREADY = 1'b0;
        S_RREADY  = 3'b000;  M_RVALID  = 1'b0;
        M_RDATA   = {DATA_W{1'b0}};  M_RRESP = 2'b00;
        case (rstate)
            R_IDLE: begin
                S_ARVALID = ar_hit & {3{M_ARVALID}};
                M_ARREADY = M_ARVALID & (ar_none | (|(ar_hit & S_ARREADY)));
            end
            R_DATA: begin
                if (rd_err) begin
                    M_RVALID = 1'b1;
                    M_RDATA  = {DATA_W{1'b0}};
                    M_RRESP  = 2'b11;                        // DECERR
                end else begin
                    S_RREADY[rd_sel] = M_RREADY;
                    M_RVALID         = S_RVALID[rd_sel];
                    M_RDATA          = S_RDATA[DATA_W*rd_sel +: DATA_W];
                    M_RRESP          = S_RRESP[2*rd_sel +: 2];
                end
            end
        endcase
    end

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            rstate <= R_IDLE;  rd_sel <= 2'd0;  rd_err <= 1'b0;
        end else begin
            case (rstate)
                R_IDLE: if (M_ARVALID && M_ARREADY) begin
                            rd_err <= ar_none;
                            rd_sel <= ar_idx;
                            rstate <= R_DATA;
                        end
                R_DATA: if (M_RVALID && M_RREADY) rstate <= R_IDLE;
            endcase
        end
    end

endmodule
