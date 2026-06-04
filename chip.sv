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
    output logic [WIDTH-1:0] m_axis_tdata,
    output logic m_axis_tvalid,
    output logic m_axis_tlast,
    input logic m_axis_tready,

    // control; note this matches ctrl
    input logic ops_val,
    output logic ops_rdy,
    output logic res_val,
    input logic res_rdy
);



endmodule