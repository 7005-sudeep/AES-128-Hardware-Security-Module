// =============================================================================
// File        : aes_fsm.sv
// Project     : AES-128 Hardware Security Module (HSM)
// Description : Master AES-128 controller FSM.
//               States: IDLE → LOAD_KEY → WAIT_KEY → INIT → ROUND → DONE
//               Iterates 10 rounds using the aes_round combinatorial engine
//               and aes_key_scheduler.  One round per clock cycle.
// =============================================================================

module aes_fsm (
    input  logic        clk,
    input  logic        rst,
    // Control inputs
    input  logic        start,          // pulse to begin encryption
    input  logic [127:0] key_in,
    input  logic [127:0] plaintext,
    // Outputs
    output logic [127:0] ciphertext,
    output logic        done            // high for one cycle when complete
);

    // -------------------------------------------------------------------------
    // FSM state encoding
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE     = 3'd0,
        S_LOAD_KEY = 3'd1,
        S_WAIT_KEY = 3'd2,
        S_INIT     = 3'd3,
        S_ROUND    = 3'd4,
        S_DONE     = 3'd5
    } fsm_state_t;

    fsm_state_t state;

    // -------------------------------------------------------------------------
    // Internal registers
    // -------------------------------------------------------------------------
    logic [3:0]   round_cnt;
    logic [127:0] state_reg;
    logic [127:0] cipher_reg;
    logic [127:0] key_reg;
    logic [127:0] pt_reg;

    // -------------------------------------------------------------------------
    // Key scheduler interface
    // -------------------------------------------------------------------------
    logic        ks_load;
    logic        ks_ready;
    logic [3:0]  ks_round_sel;
    logic [127:0] ks_rkey;

    // -------------------------------------------------------------------------
    // Round engine interface
    // -------------------------------------------------------------------------
    logic [127:0] rnd_state_in;
    logic [127:0] rnd_rkey;
    logic         rnd_is_final;
    logic [127:0] rnd_state_out;

    // -------------------------------------------------------------------------
    // Sub-module instantiations
    // -------------------------------------------------------------------------
    aes_key_scheduler U_KEYSCHED (
        .clk       (clk),
        .rst       (rst),
        .load      (ks_load),
        .key_in    (key_reg),
        .round_sel (ks_round_sel),
        .round_key (ks_rkey),
        .key_ready (ks_ready)
    );

    aes_round U_ROUND (
        .state_in  (rnd_state_in),
        .round_key (rnd_rkey),
        .is_final  (rnd_is_final),
        .state_out (rnd_state_out)
    );

    // -------------------------------------------------------------------------
    // Wire round engine inputs
    // -------------------------------------------------------------------------
    assign ks_round_sel = round_cnt;
    assign rnd_state_in = state_reg;
    assign rnd_rkey     = ks_rkey;
    assign rnd_is_final = (round_cnt == 4'd10) ? 1'b1 : 1'b0;

    // -------------------------------------------------------------------------
    // Main FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state     <= S_IDLE;
            round_cnt <= 4'd0;
            done      <= 1'b0;
            ks_load   <= 1'b0;
        end else begin
            done    <= 1'b0;    // default de-assert
            ks_load <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (start) begin
                        key_reg <= key_in;
                        pt_reg  <= plaintext;
                        state   <= S_LOAD_KEY;
                    end
                end

                S_LOAD_KEY: begin
                    ks_load <= 1'b1;    // pulse load to key scheduler
                    state   <= S_WAIT_KEY;
                end

                S_WAIT_KEY: begin
                    if (ks_ready) begin
                        state <= S_INIT;
                    end
                end

                // Round 0: AddRoundKey only (pre-round whitening)
                S_INIT: begin
                    round_cnt <= 4'd0;          // select round key 0
                    state_reg <= pt_reg ^ ks_rkey;
                    round_cnt <= 4'd1;
                    state     <= S_ROUND;
                end

                // Rounds 1-10
                S_ROUND: begin
                    state_reg <= rnd_state_out;
                    if (round_cnt == 4'd10) begin
                        cipher_reg <= rnd_state_out;
                        state      <= S_DONE;
                    end else begin
                        round_cnt <= round_cnt + 4'd1;
                    end
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

    assign ciphertext = cipher_reg;

endmodule
