module axi_lite_timer #(
    parameter ADDR_W = 32
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
    input  wire              S_RREADY,

    output wire              timer_irq
);

    reg [2:0]  ctrl;
    reg [31:0] compare, count;
    reg        match;

    assign timer_irq = ctrl[2] & match;

    function [31:0] merge(input [31:0] old_v, input [31:0] new_v, input [3:0] s);
    begin
        merge = { s[3] ? new_v[31:24] : old_v[31:24],
                  s[2] ? new_v[23:16] : old_v[23:16],
                  s[1] ? new_v[15:8]  : old_v[15:8],
                  s[0] ? new_v[7:0]   : old_v[7:0] };
    end
    endfunction

    // ---------------- write channel handshakes ----------------
    reg              aw_got, w_got;
    reg [ADDR_W-1:0] aw_l;
    reg [31:0]       w_l;
    reg [3:0]        ws_l;

    assign S_AWREADY = ~aw_got & ~S_BVALID;
    assign S_WREADY  = ~w_got  & ~S_BVALID;

    wire       do_write    = aw_got & w_got & ~S_BVALID;
    wire [1:0] wr_idx      = aw_l[3:2];
    wire       wr_in_range = (aw_l[15:4] == 12'h000);

    wire match_clr   = do_write && wr_in_range && (wr_idx == 2'd3) && ws_l[0] && w_l[0];
    wire match_event = ctrl[0] && (count == compare);

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            aw_got <= 1'b0;  w_got <= 1'b0;
            aw_l   <= {ADDR_W{1'b0}};  w_l <= 32'h0;  ws_l <= 4'h0;
            S_BVALID <= 1'b0;  S_BRESP <= 2'b00;
            ctrl <= 3'b000;  compare <= 32'h0;  count <= 32'h0;  match <= 1'b0;
        end else begin
            if (S_AWVALID && S_AWREADY) begin aw_l <= S_AWADDR; aw_got <= 1'b1; end
            if (S_WVALID  && S_WREADY)  begin w_l <= S_WDATA; ws_l <= S_WSTRB; w_got <= 1'b1; end

            // ---- register writes ----
            if (do_write) begin
                aw_got   <= 1'b0;
                w_got    <= 1'b0;
                S_BVALID <= 1'b1;
                S_BRESP  <= 2'b00;
                if (!wr_in_range) S_BRESP <= 2'b10;
                else case (wr_idx)
                    2'd0: ctrl    <= merge({29'h0, ctrl}, w_l, ws_l);
                    2'd1: compare <= merge(compare, w_l, ws_l);
                    2'd2: S_BRESP <= 2'b10;                  // COUNT is read-only
                    2'd3: ;                                  // STATUS W1C via match_clr
                endcase
            end
            if (S_BVALID && S_BREADY) S_BVALID <= 1'b0;

            // ---- counter ----
            if (!ctrl[0])                 count <= 32'h0;
            else if (count == compare) begin
                if (ctrl[1]) count <= 32'h0;                 // auto reload
            end else                      count <= count + 32'h1;

            // ---- match flag (set wins over clear) ----
            match <= (match & ~match_clr) | match_event;

            // ---- one-shot: hardware clears EN (placed last so it wins) ----
            if (match_event && !ctrl[1]) ctrl[0] <= 1'b0;
        end
    end

    // ---------------- read path ----------------
    assign S_ARREADY = ~S_RVALID;

    wire [1:0] rd_idx      = S_ARADDR[3:2];
    wire       rd_in_range = (S_ARADDR[15:4] == 12'h000);

    always @(posedge ACLK) begin
        if (!ARESETN) begin
            S_RVALID <= 1'b0;  S_RDATA <= 32'h0;  S_RRESP <= 2'b00;
        end else begin
            if (S_ARVALID && S_ARREADY) begin
                S_RVALID <= 1'b1;
                S_RRESP  <= 2'b00;
                S_RDATA  <= 32'h0;
                if (!rd_in_range) S_RRESP <= 2'b10;
                else case (rd_idx)
                    2'd0: S_RDATA <= {29'h0, ctrl};
                    2'd1: S_RDATA <= compare;
                    2'd2: S_RDATA <= count;
                    2'd3: S_RDATA <= {31'h0, match};
                endcase
            end
            if (S_RVALID && S_RREADY) S_RVALID <= 1'b0;
        end
    end

endmodule
