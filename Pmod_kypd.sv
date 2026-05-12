// =============================================================================
// File        : pmod_kypd.sv
// Project     : AES-128 Hardware Security Module (HSM)
// Description : PMOD KYPD (16-key hex keypad) matrix scanner.
//               Drives row lines one at a time and reads column lines.
//               Outputs a 4-bit hex key code and a valid strobe.
//
// PMOD KYPD Pin Mapping (JA / JB header, top row):
//   Pin 1 = Col4   Pin 2 = Col3   Pin 3 = Col2   Pin 4 = Col1
//   Pin 7 = Row4   Pin 8 = Row3   Pin 9 = Row2   Pin 10 = Row1
//
// Key map (row, col):
//         Col1  Col2  Col3  Col4
//   Row1:   1     2     3     A
//   Row2:   4     5     6     B
//   Row3:   7     8     9     C
//   Row4:   0     F     E     D
// =============================================================================

module pmod_kypd #(
    parameter int CLK_HZ  = 125_000_000,   // system clock frequency
    parameter int SCAN_HZ = 1000           // row scan rate (1 kHz)
) (
    input  logic       clk,
    input  logic       rst,
    // PMOD physical pins
    output logic [3:0] row,      // row drive (active-low)
    input  logic [3:0] col,      // column read (active-low)
    // Output
    output logic [3:0] key_code,
    output logic       key_valid
);

    // Scan clock divider: divide for 4 rows
    localparam int SCAN_DIV = CLK_HZ / (SCAN_HZ * 4);

    int                div_cnt;
    logic              scan_tick;

    // Row scanner
    logic [1:0]        row_idx;
    logic [3:0]        row_drive;

    // Debounce / sample
    logic [3:0]        col_prev;

    // Key decode LUT: KEYMAP[row][col]
    logic [3:0] KEYMAP [0:3][0:3];
    initial begin
        KEYMAP[0][0]=4'h1; KEYMAP[0][1]=4'h2; KEYMAP[0][2]=4'h3; KEYMAP[0][3]=4'hA;
        KEYMAP[1][0]=4'h4; KEYMAP[1][1]=4'h5; KEYMAP[1][2]=4'h6; KEYMAP[1][3]=4'hB;
        KEYMAP[2][0]=4'h7; KEYMAP[2][1]=4'h8; KEYMAP[2][2]=4'h9; KEYMAP[2][3]=4'hC;
        KEYMAP[3][0]=4'h0; KEYMAP[3][1]=4'hF; KEYMAP[3][2]=4'hE; KEYMAP[3][3]=4'hD;
    end

    // -------------------------------------------------------------------------
    // Scan-clock divider
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            div_cnt   <= 0;
            scan_tick <= 1'b0;
        end else if (div_cnt == SCAN_DIV - 1) begin
            div_cnt   <= 0;
            scan_tick <= 1'b1;
        end else begin
            div_cnt   <= div_cnt + 1;
            scan_tick <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // Row driver (one-hot active-low)
    // -------------------------------------------------------------------------
    always_comb begin
        case (row_idx)
            2'b00:   row_drive = 4'b1110;
            2'b01:   row_drive = 4'b1101;
            2'b10:   row_drive = 4'b1011;
            default: row_drive = 4'b0111;
        endcase
    end
    assign row = row_drive;

    // -------------------------------------------------------------------------
    // Column sampling and key decode
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            row_idx   <= 2'b00;
            key_valid <= 1'b0;
            key_code  <= 4'b0;
            col_prev  <= 4'hF;
        end else begin
            key_valid <= 1'b0;  // default

            if (scan_tick) begin
                automatic logic [3:0] col_inv;
                col_inv = ~col;     // active-low → active-high

                // Detect newly-pressed key (column rising edge)
                if (col_inv != 4'b0000 && col_prev == 4'b0000) begin
                    for (int c = 0; c < 4; c++) begin
                        if (col_inv[c]) begin
                            key_code  <= KEYMAP[row_idx][c];
                            key_valid <= 1'b1;
                        end
                    end
                end

                col_prev <= col_inv;
                row_idx  <= row_idx + 2'b01;
            end
        end
    end

endmodule
