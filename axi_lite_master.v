module axi_lite_master #(
    parameter ADDR_W = 32,
    parameter DATA_W = 32
)(
    input  wire                     ACLK,
    input  wire                     ARESETN,
 
    // ---- user command interface ----
    input  wire                     start,
    input  wire                     rw,
    input  wire [ADDR_W-1:0]        addr,
    input  wire [DATA_W-1:0]        wdata,
    input  wire [DATA_W/8-1:0]      wstrb,
    output wire                     busy,
    output reg                      done,
    output reg  [DATA_W-1:0]        rdata,
    output reg  [1:0]               resp,
 
    // ---- AXI4-Lite master port ----
    // write address channel
    output reg  [ADDR_W-1:0]        M_AWADDR,
    output wire [2:0]               M_AWPROT,
    output reg                      M_AWVALID,
    input  wire                     M_AWREADY,
    // write data channel
    output reg  [DATA_W-1:0]        M_WDATA,
    output reg  [DATA_W/8-1:0]      M_WSTRB,
    output reg                      M_WVALID,
    input  wire                     M_WREADY,
    // write response channel
    input  wire [1:0]               M_BRESP,
    input  wire                     M_BVALID,
    output reg                      M_BREADY,
    // read address channel
    output reg  [ADDR_W-1:0]        M_ARADDR,
    output wire [2:0]               M_ARPROT,
    output reg                      M_ARVALID,
    input  wire                     M_ARREADY,
    // read data channel
    input  wire [DATA_W-1:0]        M_RDATA,
    input  wire [1:0]               M_RRESP,
    input  wire                     M_RVALID,
    output reg                      M_RREADY
);
 
    // Unprivileged, secure, data access
    assign M_AWPROT = 3'b000;
    assign M_ARPROT = 3'b000;
 
    // ---------------- state encoding ----------------
    localparam [2:0] S_IDLE  = 3'd0,
                     S_WRITE = 3'd1,   // drive AW and W channels
                     S_WRESP = 3'd2,   // wait for B channel
                     S_RADDR = 3'd3,   // drive AR channel
                     S_RDATA = 3'd4,   // wait for R channel
                     S_DONE  = 3'd5;
 
    reg [2:0] state;
 
    assign busy = (state != S_IDLE);
 
    // AW and W may be accepted in different clocks; each is finished when
    // its VALID is low or its READY is high this cycle.
    wire aw_finished = ~M_AWVALID | M_AWREADY;
    wire w_finished  = ~M_WVALID  | M_WREADY;
 
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            state     <= S_IDLE;
            done      <= 1'b0;
            rdata     <= {DATA_W{1'b0}};
            resp      <= 2'b00;
            M_AWADDR  <= {ADDR_W{1'b0}};
            M_AWVALID <= 1'b0;
            M_WDATA   <= {DATA_W{1'b0}};
            M_WSTRB   <= {(DATA_W/8){1'b0}};
            M_WVALID  <= 1'b0;
            M_BREADY  <= 1'b0;
            M_ARADDR  <= {ADDR_W{1'b0}};
            M_ARVALID <= 1'b0;
            M_RREADY  <= 1'b0;
        end else begin
            done <= 1'b0;   // default: done is a one-clock pulse
 
            case (state)
                // ------------------------------------------------------
                S_IDLE: begin
                    if (start) begin
                        if (rw) begin
                            M_AWADDR  <= addr;
                            M_AWVALID <= 1'b1;
                            M_WDATA   <= wdata;
                            M_WSTRB   <= wstrb;
                            M_WVALID  <= 1'b1;
                            state     <= S_WRITE;
                        end else begin
                            M_ARADDR  <= addr;
                            M_ARVALID <= 1'b1;
                            state     <= S_RADDR;
                        end
                    end
                end
 
                // ------------------------------------------------------
                S_WRITE: begin
                    if (M_AWVALID && M_AWREADY) M_AWVALID <= 1'b0;
                    if (M_WVALID  && M_WREADY)  M_WVALID  <= 1'b0;
 
                    if (aw_finished && w_finished) begin
                        M_BREADY <= 1'b1;
                        state    <= S_WRESP;
                    end
                end
 
                // ------------------------------------------------------
                S_WRESP: begin
                    if (M_BVALID && M_BREADY) begin
                        resp     <= M_BRESP;
                        M_BREADY <= 1'b0;
                        state    <= S_DONE;
                    end
                end
 
                // ------------------------------------------------------
                S_RADDR: begin
                    if (M_ARVALID && M_ARREADY) begin
                        M_ARVALID <= 1'b0;
                        M_RREADY  <= 1'b1;
                        state     <= S_RDATA;
                    end
                end
 
                // ------------------------------------------------------
                S_RDATA: begin
                    if (M_RVALID && M_RREADY) begin
                        rdata    <= M_RDATA;
                        resp     <= M_RRESP;
                        M_RREADY <= 1'b0;
                        state    <= S_DONE;
                    end
                end
 
                // ------------------------------------------------------
                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end
 
                default: state <= S_IDLE;
            endcase
        end
    end
 
endmodule

