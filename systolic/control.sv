
module control (
    input logic clk,
    input logic rst,

    // chip (outside world)
    input logic ops_val, // outside says matrices are ready to send
    output logic ops_rdy, // we are ready to operate
    output logic res_val, // we say results are ready to send
    input logic res_rdy, // outside are ready for result

    // datapath
    input logic loaded,
    input logic compute_done,
    output logic compute_busy
);

typedef enum logic [1:0] {
    IDLE = 2'b00,
    BUSY = 2'b01,
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
    // set port outputs to default
    ops_rdy = 1'b0;
    res_val = 1'b0;
    compute_busy = 1'b0;
    next_state = curr_state;

    case (curr_state)
        IDLE: begin
            ops_rdy = 1'b1;
            if (loaded && ops_val) begin
                next_state = BUSY;
            end
        end
        BUSY: begin // remember this covers the ENTIRE MATRIX ALL ENTRIES UNTIL FULLY DONE
            compute_busy = 1'b1;
            if (compute_done) begin // only leave when the last entry actually finalizes
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