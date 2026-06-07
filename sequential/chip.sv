// wires datapath and control and exposes interface to outside input

module chip #(
    parameter N = 4,
    parameter WIDTH = 8
)(
    input logic clk,
    input logic rst,

    // datapath-slave; note this matches dp
    input logic [WIDTH-1:0] s_axis_tdata,
    input logic s_axis_tvalid,
    input logic s_axis_tlast,
    output logic s_axis_tready,

    // datapath-master; note this matches dp
    output logic [2*WIDTH+$clog2(N)-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    output logic m_axis_tlast,
    input logic m_axis_tready,

    // control; note this matches ctrl
    input logic ops_val,
    output logic ops_rdy,
    output logic res_val,
    input logic res_rdy
);

// dp and ctrl internal wires
logic mac;
logic i_done;
logic j_done;
logic k_done;
logic loaded;

// instantiations
datapath dp (
    .clk (clk),
    .rst (rst),
    .s_axis_tdata (s_axis_tdata),
    .s_axis_tvalid (s_axis_tvalid),
    .s_axis_tlast (s_axis_tlast),
    .s_axis_tready (s_axis_tready),
    .m_axis_tdata (m_axis_tdata),
    .m_axis_tvalid (m_axis_tvalid),
    .m_axis_tlast (m_axis_tlast),
    .m_axis_tready (m_axis_tready),
    .i_done (i_done),
    .j_done (j_done),
    .k_done (k_done),
    .mac (mac),
    .loaded (loaded)
);

control ctrl (
    .clk (clk),
    .rst (rst),
    .ops_val (ops_val),
    .ops_rdy (ops_rdy),
    .res_val (res_val),
    .res_rdy (res_rdy),
    .i_done (i_done),
    .j_done (j_done),
    .k_done (k_done),
    .mac (mac),
    .loaded (loaded),
    .result_pending (m_axis_tvalid)
);

endmodule