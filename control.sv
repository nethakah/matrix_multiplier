// state machine IDLE/CALC/DONE
// tells datapath.sv when to load, when to MAC, when to ++counter
// watch status signals from datapath.sv
// handle ready-valid interface

module control (
    input logic clk,
    input logic rst,

    // chip (outside world)
    input logic ops_val, // outside says matrices are ready to go
    output logic ops_rdy, // we are ready to operate
    output logic res_val, // we say results are ready to go
    input logic res_rdy, // outside are ready for result

    // datapath
    output logic mac,
    input logic i_done,
    input logic j_done,
    input logic k_done
);

typedef enum logic [1:0] {
    IDLE = 2'b00,
    CALC = 2'b01,
    DONE = 2'b10
} state_t;

state_t curr_state;
state_t next_state;

always_ff @(posedge clk) begin
    if (rst)
        curr_state <= IDLE;
    else
        curr_state <= next_state;
end

always_comb begin
    ops_rdy = 1'b0;
    res_val = 1'b0;
    next_state = curr_state;

    case (curr_state)
        IDLE: begin
        
        end

        CALC: begin
        end
        
        DONE: begin
        end
    endcase
end

endmodule