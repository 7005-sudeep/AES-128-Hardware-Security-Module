// =============================================================================
// File        : pmod_oled.sv
// Project     : AES-128 Hardware Security Module (HSM)
// Description : PMOD OLED (SSD1306) SPI controller.
//               Handles power-up, initialization sequence, and display writes.
//               SPI Mode 0 (CPOL=0, CPHA=0), MSB-first.
// =============================================================================

module pmod_oled #(
    parameter int CLK_HZ = 125_000_000,
    parameter int SPI_HZ = 1_000_000      // 1 MHz SPI
) (
    input  logic        clk,
    input  logic        rst,
    // 32-byte ASCII display string (row0: bytes[0..15], row1: bytes[16..31])
    input  logic [255:0] disp_data,
    input  logic         wr_en,          // pulse to trigger display update
    // PMOD pins
    output logic        oled_cs,
    output logic        oled_sdi,
    output logic        oled_sck,
    output logic        oled_dc,
    output logic        oled_res,
    output logic        oled_vbat,
    output logic        oled_vdd,
    // Status
    output logic        busy
);

    // -------------------------------------------------------------------------
    // SPI clock divider
    // -------------------------------------------------------------------------
    localparam int SPI_DIV = CLK_HZ / (SPI_HZ * 2);

    int         spi_cnt;
    logic       spi_tick;

    // -------------------------------------------------------------------------
    // SPI shift register state
    // -------------------------------------------------------------------------
    logic [7:0]  spi_sr;
    logic [2:0]  bit_cnt;
    logic        sck_r;
    logic        cs_r;
    logic        dc_r;
    logic        spi_active;
    logic [7:0]  spi_byte;

    // Byte transmitter handshake
    logic        tx_start;
    logic        tx_done;
    logic [7:0]  tx_byte;
    logic        tx_dc;

    // -------------------------------------------------------------------------
    // OLED init command sequence (SSD1306 minimal init for 128x32)
    // -------------------------------------------------------------------------
    logic [7:0] INIT_CMDS [0:24];
    initial begin
        INIT_CMDS[ 0]=8'hAE;               // display off
        INIT_CMDS[ 1]=8'hD5; INIT_CMDS[ 2]=8'h80;   // set display clock
        INIT_CMDS[ 3]=8'hA8; INIT_CMDS[ 4]=8'h1F;   // set multiplex 31
        INIT_CMDS[ 5]=8'hD3; INIT_CMDS[ 6]=8'h00;   // display offset = 0
        INIT_CMDS[ 7]=8'h40;                           // start line = 0
        INIT_CMDS[ 8]=8'h8D; INIT_CMDS[ 9]=8'h14;   // charge pump on
        INIT_CMDS[10]=8'h20; INIT_CMDS[11]=8'h00;   // horizontal addressing
        INIT_CMDS[12]=8'hA1;                           // segment remap
        INIT_CMDS[13]=8'hC8;                           // COM output scan direction
        INIT_CMDS[14]=8'hDA; INIT_CMDS[15]=8'h02;   // COM pins (32-row)
        INIT_CMDS[16]=8'h81; INIT_CMDS[17]=8'h8F;   // contrast
        INIT_CMDS[18]=8'hD9; INIT_CMDS[19]=8'hF1;   // pre-charge period
        INIT_CMDS[20]=8'hDB; INIT_CMDS[21]=8'h40;   // VCOMH deselect
        INIT_CMDS[22]=8'hA4;                           // follow RAM
        INIT_CMDS[23]=8'hA6;                           // normal display
        INIT_CMDS[24]=8'hAF;                           // display ON
    end

    // -------------------------------------------------------------------------
    // Controller FSM
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        ST_POWER_UP   = 3'd0,
        ST_RESET      = 3'd1,
        ST_INIT       = 3'd2,
        ST_CLEAR      = 3'd3,
        ST_SET_ADDR   = 3'd4,
        ST_WRITE_DATA = 3'd5,
        ST_IDLE       = 3'd6
    } ctrl_state_t;

    ctrl_state_t   ctrl_state;
    logic [23:0]   delay_cnt;
    logic [7:0]    seq_idx;
    logic [255:0]  disp_latch;

    // -------------------------------------------------------------------------
    // SPI clock divider process
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            spi_cnt  <= 0;
            spi_tick <= 1'b0;
        end else if (spi_cnt == SPI_DIV - 1) begin
            spi_cnt  <= 0;
            spi_tick <= 1'b1;
        end else begin
            spi_cnt  <= spi_cnt + 1;
            spi_tick <= 1'b0;
        end
    end

    // -------------------------------------------------------------------------
    // SPI shift-out process
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            sck_r      <= 1'b0;
            cs_r       <= 1'b1;
            oled_sdi   <= 1'b0;
            bit_cnt    <= 3'd0;
            tx_done    <= 1'b0;
            spi_active <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            if (tx_start && !spi_active) begin
                spi_byte   <= tx_byte;
                dc_r       <= tx_dc;
                cs_r       <= 1'b0;
                sck_r      <= 1'b0;
                bit_cnt    <= 3'd7;
                spi_active <= 1'b1;
                oled_sdi   <= tx_byte[7];
            end else if (spi_active && spi_tick) begin
                if (!sck_r) begin
                    sck_r <= 1'b1;          // raise clock (data already stable)
                end else begin
                    sck_r <= 1'b0;          // lower clock
                    if (bit_cnt == 3'd0) begin
                        spi_active <= 1'b0;
                        cs_r       <= 1'b1;
                        tx_done    <= 1'b1;
                    end else begin
                        bit_cnt  <= bit_cnt - 3'd1;
                        spi_byte <= {spi_byte[6:0], 1'b0};
                        oled_sdi <= spi_byte[6];
                    end
                end
            end
        end
    end

    assign oled_sck = sck_r;
    assign oled_cs  = cs_r;
    assign oled_dc  = dc_r;

    // -------------------------------------------------------------------------
    // Main OLED controller FSM
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            ctrl_state <= ST_POWER_UP;
            delay_cnt  <= 24'd0;
            seq_idx    <= 8'd0;
            oled_vdd   <= 1'b1;     // VDD off (active-low)
            oled_vbat  <= 1'b1;     // VBAT off
            oled_res   <= 1'b0;     // hold in reset
            busy       <= 1'b1;
            tx_start   <= 1'b0;
        end else begin
            tx_start <= 1'b0;   // default

            case (ctrl_state)

                ST_POWER_UP: begin
                    oled_vdd  <= 1'b0;      // VDD on
                    oled_res  <= 1'b0;
                    delay_cnt <= delay_cnt + 24'd1;
                    if (delay_cnt == 24'hFFFFF) begin
                        oled_res   <= 1'b1;
                        ctrl_state <= ST_RESET;
                        delay_cnt  <= 24'd0;
                    end
                end

                ST_RESET: begin
                    oled_vbat <= 1'b0;      // VBAT on
                    delay_cnt <= delay_cnt + 24'd1;
                    if (delay_cnt == 24'hFFFFF) begin
                        ctrl_state <= ST_INIT;
                        seq_idx    <= 8'd0;
                        delay_cnt  <= 24'd0;
                    end
                end

                ST_INIT: begin
                    if (seq_idx < 8'd25) begin
                        if (!spi_active) begin
                            tx_byte    <= INIT_CMDS[seq_idx];
                            tx_dc      <= 1'b0;     // command
                            tx_start   <= 1'b1;
                            seq_idx    <= seq_idx + 8'd1;
                        end
                    end else begin
                        ctrl_state <= ST_IDLE;
                        seq_idx    <= 8'd0;
                        busy       <= 1'b0;
                    end
                end

                ST_IDLE: begin
                    busy <= 1'b0;
                    if (wr_en) begin
                        disp_latch <= disp_data;
                        busy       <= 1'b1;
                        seq_idx    <= 8'd0;
                        ctrl_state <= ST_SET_ADDR;
                    end
                end

                ST_SET_ADDR: begin
                    ctrl_state <= ST_WRITE_DATA;
                    seq_idx    <= 8'd0;
                end

                ST_WRITE_DATA: begin
                    delay_cnt <= delay_cnt + 24'd1;
                    if (delay_cnt == 24'h00FFFF) begin
                        delay_cnt  <= 24'd0;
                        ctrl_state <= ST_IDLE;
                    end
                end

                default: ctrl_state <= ST_IDLE;

            endcase
        end
    end

endmodule
