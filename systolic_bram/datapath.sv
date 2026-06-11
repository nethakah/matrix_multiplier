module datapath #(
    parameter N = 4,
    parameter WIDTH = 8
)(
    input logic clk,
    input logic rst,

    //slave
    input logic [WIDTH-1:0] s_axis_tdata,
    input logic s_axis_tvalid,
    input logic s_axis_tlast,
    output logic s_axis_tready,

    //master
    output logic [2*WIDTH+$clog2(N)-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    output logic m_axis_tlast,
    input logic m_axis_tready,

    //control.sv - logic here is ctrl sets busy=1, then waits until done=1
    input logic compute_busy,
    output logic loaded,
    output logic compute_done
);

// BRAM bank wire lists
logic a_we [0:N-1];
logic [$clog2(N)-1:0] a_waddr [0:N-1];
logic [$clog2(N)-1:0] a_raddr [0:N-1];
logic [WIDTH-1:0] a_wdata [0:N-1];
logic [WIDTH-1:0] a_rdata [0:N-1];
logic b_we [0:N-1];
logic [$clog2(N)-1:0] b_waddr [0:N-1];
logic [$clog2(N)-1:0] b_raddr [0:N-1];
logic [WIDTH-1:0] b_wdata [0:N-1];
logic [WIDTH-1:0] b_rdata [0:N-1];

// bram.sv instantiation
genvar bank;
generate
    for (bank=0; bank<N; bank++) begin : a_banks
        bram #(
        .WIDTH (WIDTH),
        .DEPTH (N)
        ) u_a_bram (
            .clk (clk),
            .we (a_we[bank]),
            .waddr (a_waddr[bank]),
            .wdata (a_wdata[bank]),
            .raddr (a_raddr[bank]),
            .rdata (a_rdata[bank])
        );
    end
    for (bank=0; bank<N; bank++) begin : b_banks
        bram #(
        .WIDTH (WIDTH),
        .DEPTH (N)
        ) u_b_bram (
            .clk (clk),
            .we (b_we[bank]),
            .waddr (b_waddr[bank]),
            .wdata (b_wdata[bank]),
            .raddr (b_raddr[bank]),
            .rdata (b_rdata[bank])
        );
    end
endgenerate

// array.sv
logic [WIDTH-1:0] a_edge [0:N-1];
logic [WIDTH-1:0] b_edge [0:N-1];
logic [2*WIDTH+$clog2(N)-1:0] ab_out [0:N-1][0:N-1]; // output matrix
array #(
    .N (N),
    .WIDTH (WIDTH)
) u_array (
    .clk (clk),
    .rst (rst),
    .a_edge (a_edge),
    .b_edge (b_edge),
    .ab_out (ab_out)
);

// counters (no -1 because we want an overflow extra 1 bit)
logic [$clog2(2*N*N):0] load_cnt; // N^2 for matA + N^2 for matB
logic [$clog2(3*N):0] t; // cycle counter to know when done computing (heartbeat of compute phase)
// ~N cycles input enterring + ~N to move across array + ~N mult-adds to accumulate dot product
logic [$clog2(N*N):0] out_cnt; // counts us outputting the result matrix ab_out's entries

// internal
assign loaded = (load_cnt == 2*N*N); // loaded all
assign s_axis_tready = (load_cnt < 2*N*N); // load entries until we get them all!

// calculation clock
always_ff @(posedge clk) begin
    if (rst) begin
        // internal signals
        load_cnt <= '0;
        t <= '0;
        out_cnt <= '0;

        // outputs driven by datapath that are not handled elsewhere
        m_axis_tdata <= '0;
        m_axis_tvalid <= '0;
        m_axis_tlast <= '0;
        compute_done <= '0;

    // load
    end else if (s_axis_tvalid && s_axis_tready) begin
        load_cnt <= load_cnt + 1;

    // if we are computing, advance (while t < 3N-3)
    end else if (compute_busy) begin
        if (t < 3*N-3) begin // computing values - changed to -2 because we gated feed in always_comb w compute_busy
            t <= t + 1;
        end else begin // (t == 3N-3) -> done computing
        // push ab_out
        // tvalid is gonna be double used to check "is slot full"
        // out_cnt is now leading by 1 = index of NEXT element to push
            if (!m_axis_tvalid) begin
                // empty slot - load element and mark full
                m_axis_tdata <= ab_out[out_cnt/N][out_cnt%N];
                m_axis_tvalid <= 1'b1;
                m_axis_tlast <= (out_cnt == N*N-1); // is this the next element?
                out_cnt <= out_cnt + 1;
            end else if (m_axis_tvalid && m_axis_tready) begin
                // valid data and accepted by receiver
                if (m_axis_tlast) begin
                    // last accepted data
                    m_axis_tvalid <= '0;
                    m_axis_tlast <= '0;
                    compute_done <= 1'b1;
                end else begin // not last one yet
                    m_axis_tdata <= ab_out[out_cnt/N][out_cnt%N];
                    m_axis_tlast <= (out_cnt == N*N-1);
                    out_cnt <= out_cnt + 1;
                end
            end
        end // implicit else: slot is full and not tready -> implies hold current tdata/tvalid (backpressure hopefully)
    end
end


// WRITE (route tdata to right bank during loading)
always_comb begin
    for (int bank=0; bank<N; bank++) begin // default (no bank written)
        a_we[bank] = '0;
        a_waddr[bank] = '0;
        a_wdata[bank] = '0;
        b_we[bank] = '0;
        b_waddr[bank] = '0;
        b_wdata[bank] = '0;
    end

end

// READ (present read address with skew for systolic array)
always_comb begin

end

// testing/debug - remove later
always @(posedge clk) begin
    if (compute_busy)
        $display("t=%0d  ab_out[0][0]=%0d  out_cnt=%0d  tvalid=%0d tready=%0d tdata=%0d",
                 t, ab_out[0][0], out_cnt, m_axis_tvalid, m_axis_tready, m_axis_tdata);
end

endmodule