// state machine IDLE/CALC/DONE
// tells datapath.sv when to load, when to MAC, when to ++counter
// watch status signals from datapath.sv
// handle ready-valid interface

module control (
    input logic clk,
    input logic rst,

    // chip (outside world)
    input logic ops_val, // outside says matrices are ready to send
    output logic ops_rdy, // we are ready to operate
    output logic res_val, // we say results are ready to send
    input logic res_rdy, // outside are ready for result

    // datapath
    output logic mac,
    input logic i_done,
    input logic j_done,
    input logic k_done,
    input logic loaded,
    input logic result_pending
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
    mac = 1'b0;
    next_state = curr_state;

    case (curr_state)
        IDLE: begin
            ops_rdy = 1'b1;
            if (loaded && ops_val) begin
                next_state = CALC;
            end
        end
        CALC: begin // remember this covers the ENTIRE MATRIX ALL ENTRIES UNTIL FULLY DONE
            mac = !result_pending; // pause computing while a finished result waits to be taken
            if (i_done && j_done && k_done) begin // only leave when the last entry actually finalizes
                next_state = DONE;
            end
        end
        DONE: begin
            res_val = 1'b1;
            if (res_rdy) begin
                next_state = IDLE;
            end
        end
    endcase
end

endmodule