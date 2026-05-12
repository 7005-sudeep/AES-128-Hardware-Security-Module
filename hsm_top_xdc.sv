## =============================================================================
## File        : hsm_top.xdc
## Project     : AES-128 Hardware Security Module (HSM)
## Board       : Zybo Z7-10 / Z7-20 (XC7Z010CLG400-1)
## Description : Pin constraints and timing for 125 MHz operation.
## =============================================================================

## ---------------------------------------------------------------------------
## System Clock - 125 MHz on-board clock (Zybo Z7 system clock)
## ---------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -period 8.000 -name sys_clk_pin -waveform {0.000 4.000} [get_ports clk]

## ---------------------------------------------------------------------------
## Buttons (active-high on Zybo Z7)
##   BTN0 = reset, BTN1 = key attack, BTN2 = PT attack / return, BTN3 = next nibble
## ---------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN K19 IOSTANDARD LVCMOS33} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {btn[3]}]

## ---------------------------------------------------------------------------
## LEDs (active-high)
## ---------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN M14 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN M15 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN G14 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

## ---------------------------------------------------------------------------
## PMOD JA - KYPD keypad
##   JA1=kypd_row[0]  JA2=kypd_row[1]  JA3=kypd_row[2]  JA4=kypd_row[3]
##   JA7=kypd_col[0]  JA8=kypd_col[1]  JA9=kypd_col[2]  JA10=kypd_col[3]
## ---------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {kypd_row[0]}]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {kypd_row[1]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {kypd_row[2]}]
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports {kypd_row[3]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports {kypd_col[0]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports {kypd_col[1]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {kypd_col[2]}]
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {kypd_col[3]}]

## ---------------------------------------------------------------------------
## PMOD JB - OLED (ports kept for compatibility; OLED driven to safe idle)
##   JB1=oled_cs  JB2=oled_sdi  JB3=oled_sck  JB4=oled_dc
##   JB7=oled_res JB8=oled_vbat JB9=oled_vdd
## ---------------------------------------------------------------------------
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports oled_cs]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports oled_sdi]
set_property -dict {PACKAGE_PIN V20 IOSTANDARD LVCMOS33} [get_ports oled_sck]
set_property -dict {PACKAGE_PIN W20 IOSTANDARD LVCMOS33} [get_ports oled_dc]
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports oled_res]
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports oled_vbat]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports oled_vdd]

## ---------------------------------------------------------------------------
## Timing constraints
## ---------------------------------------------------------------------------
## False path on async reset (synchronous reset used in RTL, but safe to add)
set_false_path -from [get_ports {btn[0]}]

## Multi-cycle path: key scheduler takes 40+ cycles; relax combinatorial paths
## through W[] array during EXPAND state (read-after-write is sequential)
## No explicit MCP needed: all W[] reads use registered values from prior cycle.

## ---------------------------------------------------------------------------
## Bitstream / configuration
## ---------------------------------------------------------------------------
set_property BITSTREAM.GENERAL.COMPRESS TRUE  [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4  [current_design]
set_property CONFIG_MODE SPIx4                [current_design]
