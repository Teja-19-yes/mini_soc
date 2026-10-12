module axi_lite_regs #(
    parameter ADDR_W   = 32,
    parameter [31:0] ID_VALUE = 32'h4158_4C31      // "AXL1"
)(
    input  wire              ACLK,
    input  wire              ARESETN,
 
    // write address channel
    input  wire [ADDR_W-1:0] S_AWADDR,
    input  wire              S_AWVALID,
    output wire              S_AWREADY,
    // write data channel
    input  wire [31:0]       S_WDATA,
    input  wire [3:0]        S_WSTRB,
    input  wire              S_WVALID,
    output wire              S_WREADY,
    // write response channel
    output reg  [1:0]        S_BRESP,
    output reg               S_BVALID,
    input  wire              S_BREADY,
    // read address channel
    input  wire [ADDR_W-1:0] S_ARADDR,
    input  wire              S_ARVALID,
    output wire              S_ARREADY,
    // read data channel
    output reg  [31:0]       S_RDATA,
    output reg  [1:0]        S_RRESP,
    output reg               S_RVALID,
    input  wire              S_RREADY,
 
    // register-bank side
    output wire [31:0]       ctrl_out,
    output wire [31:0]       data_out,
    input  wire [31:0]       status_set     // pulse a bit to set a STATUS flag
);
 
    reg [31:0] ctrl, status, data;
    assign ctrl_out = ctrl;
    assign data_out = data;
 
    // merge new data into old data according to byte strobes
    function [31:0] merge(input [31:0] old_v, input [31:0] new_v, input [3:0] s);
    begin
        merge = { s[3] ? new_v[31:24] : old_v[31:24],
                  s[2] ? new_v[23:16] : old_v[23:16],
                  s[1] ? new_v[15:8]  : old_v[15:8],
                  s[0] ? new_v[7:0]   : old_v[7:0] };
    end
    endfunction
 
    // ---------------- write path ----------------
    reg              aw_got, w_got;
    reg [ADDR_W-1:0] aw_l;
    reg [31:0]       w_l;
    reg [3:0]        ws_l;
 
    assign S_AWREADY = ~aw_got & ~S_BVALID;
    assign S_WREADY  = ~w_got  & ~S_BVALID;
 
    wire       do_write    = aw_got & w_got & ~S_BVALID;
    wire [1:0] wr_idx      = aw_l[3:2];
    wire       wr_in_range = (aw_l[15:4] == 12'h000);
 
    wire [31:0] status_clr = (do_write && wr_in_range && wr_idx == 2'd1)
                             ? merge(32'h0, w_l, ws_l) : 32'h0;
 
    always @(posedge ACLK) begin
        if (!ARESETN) begin
            aw_got <= 1'b0;  w_got <= 1'b0;
            aw_l   <= {ADDR_W{1'b0}};  w_l <= 32'h0;  ws_l <= 4'h0;
            S_BVALID <= 1'b0;  S_BRESP <= 2'b00;
            ctrl <= 32'h0;  status <= 32'h0;  data <= 32'h0;
        end else begin
            if (S_AWVALID && S_AWREADY) begin aw_l <= S_AWADDR; aw_got <= 1'b1; end
            if (S_WVALID  && S_WREADY)  begin w_l <= S_WDATA; ws_l <= S_WSTRB; w_got <= 1'b1; end
 
            if (do_write) begin
                aw_got   <= 1'b0;
                w_got    <= 1'b0;
                S_BVALID <= 1'b1;
                S_BRESP  <= 2'b00;
                if (!wr_in_range) S_BRESP <= 2'b10;
                else case (wr_idx)
                    2'd0: ctrl <= merge(ctrl, w_l, ws_l);
                    2'd1: ;                                  // W1C handled via status_clr
                    2'd2: data <= merge(data, w_l, ws_l);
                    2'd3: S_BRESP <= 2'b10;                  // ID is read-only
                endcase
            end
            if (S_BVALID && S_BREADY) S_BVALID <= 1'b0;
 
            // set wins over clear if both happen in the same clock
            status <= (status & ~status_clr) | status_set;
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
                if (!rd_in_range) begin
                    S_RDATA <= 32'h0;  S_RRESP <= 2'b10;
                end else begin
                    S_RRESP <= 2'b00;
                    case (rd_idx)
                        2'd0: S_RDATA <= ctrl;
                        2'd1: S_RDATA <= status;
                        2'd2: S_RDATA <= data;
                        2'd3: S_RDATA <= ID_VALUE;
                    endcase
                end
            end
            if (S_RVALID && S_RREADY) S_RVALID <= 1'b0;
        end
    end
 
endmodule
 
