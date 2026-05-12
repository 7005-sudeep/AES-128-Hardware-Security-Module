// =============================================================================
// File        : hsm_top.sv
// Project     : AES-128 Hardware Security Module (HSM)
// Board       : Zybo Z7 (Zynq-7000)
//
// REVISION    : v3 - LED-only demo (OLED bypassed, black screen workaround)
//               Ciphertext displayed 4 bits (1 nibble) at a time on LED[3:0].
//               BTN3 cycles to next nibble.
//
// == Button Map ==============================================================
//   BTN0 = Full reset
//   BTN1 = Attack Demo A: 1-bit KEY tamper  (avalanche)
//   BTN2 = Attack Demo B: 1-bit PT tamper   (diffusion)
//           ... also: Return to normal from attack display
//   BTN3 = Next nibble  (cycles ciphertext nibbles 0-31 on LEDs)
//
// == LED Map =================================================================
//   PH_KEY          -> "0001"  (collecting key)
//   PH_PLAIN        -> "0011"  (collecting plaintext)
//   PH_ENCRYPT      -> "0110"  (AES running)
//   PH_DISPLAY      -> shows nibble N of ct_orig
//   PH_ATCK_SETUP   -> "0110"
//   PH_ATCK_ENCRYPT -> "0110"
//   PH_ATCK_DISPLAY -> shows nibble N of ct_tamp
// =============================================================================

module hsm_top (
    input  logic       clk,
    input  logic [3:0] btn,
    output logic [3:0] led,
    // PMOD KYPD (JA)
    output logic [3:0] kypd_row,
    input  logic [3:0] kypd_col,
    // PMOD OLED (JB) - kept for constraints compatibility; OLED stays off
    output logic       oled_cs,
    output logic       oled_sdi,
    output logic       oled_sck,
    output logic       oled_dc,
    output logic       oled_res,
    output logic       oled_vbat,
    output logic       oled_vdd
);

    // -------------------------------------------------------------------------
    // OLED safe idle values
    // -------------------------------------------------------------------------
    assign oled_cs   = 1'b1;   // deselected (active-low)
    assign oled_sdi  = 1'b0;
    assign oled_sck  = 1'b0;
    assign oled_dc   = 1'b0;
    assign oled_res  = 1'b0;   // held in reset
    assign oled_vbat = 1'b0;   // power off
    assign oled_vdd  = 1'b0;   // power off

    // -------------------------------------------------------------------------
    // Reset = BTN0
    // -------------------------------------------------------------------------
    logic rst;
    assign rst = btn[0];

    // -------------------------------------------------------------------------
    // Button edge detection
    // -------------------------------------------------------------------------
    logic [3:0] btn_r;
    logic [3:0] btn_rise;

    always_ff @(posedge clk) begin
        btn_r <= btn;
    end
    assign btn_rise = btn & ~btn_r;

    // -------------------------------------------------------------------------
    // KYPD outputs
    // -------------------------------------------------------------------------
    logic [3:0] key_code;
    logic       key_valid;

    // -------------------------------------------------------------------------
    // Data registers
    // -------------------------------------------------------------------------
    logic [127:0] key_reg;
    logic [127:0] pt_reg;
    logic [127:0] ct_orig;
    logic [127:0] ct_tamp;

    logic [5:0]   nibble_cnt;   // 0-31
    logic [4:0]   nibble_sel;   // 0-31
    logic [3:0]   disp_nibble;
    logic [127:0] disp_ct;

    // -------------------------------------------------------------------------
    // Attack mux
    // -------------------------------------------------------------------------
    logic [127:0] aes_key_in;
    logic [127:0] aes_pt_in;
    logic         atk_key;
    logic         atk_pt;

    assign aes_key_in = atk_key ? {key_reg[127:1], ~key_reg[0]} : key_reg;
    assign aes_pt_in  = atk_pt  ? {pt_reg[127:1],  ~pt_reg[0]}  : pt_reg;

    // -------------------------------------------------------------------------
    // AES FSM signals
    // -------------------------------------------------------------------------
    logic        aes_start;
    logic        aes_done;
    logic [127:0] ciphertext;

    // -------------------------------------------------------------------------
    // Instantiations
    // -------------------------------------------------------------------------
    pmod_kypd #(
        .CLK_HZ  (125_000_000),
        .SCAN_HZ (1000)
    ) U_KYPD (
        .clk      (clk),
        .rst      (rst),
        .row      (kypd_row),
        .col      (kypd_col),
        .key_code (key_code),
        .key_valid(key_valid)
    );

    aes_fsm U_AES (
        .clk       (clk),
        .rst       (rst),
        .start     (aes_start),
        .key_in    (aes_key_in),
        .plaintext (aes_pt_in),
        .ciphertext(ciphertext),
        .done      (aes_done)
    );

    // -------------------------------------------------------------------------
    // Nibble extractor (combinatorial)
    // Extracts nibble nibble_sel from disp_ct (nibble 0 = MSB nibble)
    // -------------------------------------------------------------------------
    always_comb begin
        disp_nibble = 4'b0;
        for (int i = 0; i < 32; i++) begin
            if (nibble_sel == 5'(i)) begin
                disp_nibble = disp_ct[127 - i*4 -: 4];
            end
        end
    end

    // -------------------------------------------------------------------------
    // FSM states
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        PH_KEY          = 3'd0,
        PH_PLAIN        = 3'd1,
        PH_ENCRYPT      = 3'd2,
        PH_DISPLAY      = 3'd3,
        PH_ATCK_SETUP   = 3'd4,
        PH_ATCK_ENCRYPT = 3'd5,
        PH_ATCK_DISPLAY = 3'd6
    } phase_t;

    phase_t phase;

    // -------------------------------------------------------------------------
    // Main FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            phase      <= PH_KEY;
            nibble_cnt <= 6'd0;
            nibble_sel <= 5'd0;
            key_reg    <= 128'd0;
            pt_reg     <= 128'd0;
            ct_orig    <= 128'd0;
            ct_tamp    <= 128'd0;
            atk_key    <= 1'b0;
            atk_pt     <= 1'b0;
            aes_start  <= 1'b0;
            disp_ct    <= 128'd0;
            led        <= 4'b0000;
        end else begin
            aes_start <= 1'b0;  // default de-assert

            case (phase)

                // PH_KEY: collect 32 nibbles for 128-bit key
                PH_KEY: begin
                    led <= 4'b0001;
                    if (key_valid) begin
                        key_reg    <= {key_reg[123:0], key_code};
                        nibble_cnt <= nibble_cnt + 6'd1;
                        if (nibble_cnt == 6'd31) begin
                            nibble_cnt <= 6'd0;
                            phase      <= PH_PLAIN;
                        end
                    end
                end

                // PH_PLAIN: collect 32 nibbles for 128-bit plaintext
                PH_PLAIN: begin
                    led <= 4'b0011;
                    if (key_valid) begin
                        pt_reg     <= {pt_reg[123:0], key_code};
                        nibble_cnt <= nibble_cnt + 6'd1;
                        if (nibble_cnt == 6'd31) begin
                            nibble_cnt <= 6'd0;
                            atk_key    <= 1'b0;
                            atk_pt     <= 1'b0;
                            phase      <= PH_ENCRYPT;
                        end
                    end
                end

                // PH_ENCRYPT: run AES, wait for done
                PH_ENCRYPT: begin
                    led       <= 4'b0110;
                    aes_start <= 1'b1;
                    if (aes_done) begin
                        ct_orig    <= ciphertext;
                        disp_ct    <= ciphertext;
                        nibble_sel <= 5'd0;
                        phase      <= PH_DISPLAY;
                    end
                end

                // PH_DISPLAY: show CT nibble on LEDs
                PH_DISPLAY: begin
                    led <= disp_nibble;

                    if (btn_rise[3]) begin
                        nibble_sel <= (nibble_sel == 5'd31) ? 5'd0 : nibble_sel + 5'd1;
                    end

                    if (btn_rise[1]) begin
                        atk_key    <= 1'b1;
                        atk_pt     <= 1'b0;
                        nibble_sel <= 5'd0;
                        phase      <= PH_ATCK_SETUP;
                    end

                    if (btn_rise[2]) begin
                        atk_key    <= 1'b0;
                        atk_pt     <= 1'b1;
                        nibble_sel <= 5'd0;
                        phase      <= PH_ATCK_SETUP;
                    end
                end

                // PH_ATCK_SETUP: one cycle for mux to settle
                PH_ATCK_SETUP: begin
                    led   <= 4'b0110;
                    phase <= PH_ATCK_ENCRYPT;
                end

                // PH_ATCK_ENCRYPT: re-encrypt with tampered input
                PH_ATCK_ENCRYPT: begin
                    led       <= 4'b0110;
                    aes_start <= 1'b1;
                    if (aes_done) begin
                        ct_tamp    <= ciphertext;
                        disp_ct    <= ciphertext;
                        nibble_sel <= 5'd0;
                        phase      <= PH_ATCK_DISPLAY;
                    end
                end

                // PH_ATCK_DISPLAY: show tampered CT nibbles
                PH_ATCK_DISPLAY: begin
                    led <= disp_nibble;

                    if (btn_rise[3]) begin
                        nibble_sel <= (nibble_sel == 5'd31) ? 5'd0 : nibble_sel + 5'd1;
                    end

                    if (btn_rise[2]) begin
                        atk_key    <= 1'b0;
                        atk_pt     <= 1'b0;
                        disp_ct    <= ct_orig;
                        nibble_sel <= 5'd0;
                        phase      <= PH_DISPLAY;
                    end
                end

                default: phase <= PH_KEY;

            endcase
        end
    end

endmodule
