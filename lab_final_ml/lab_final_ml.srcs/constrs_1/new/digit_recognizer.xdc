## =============================================================================
## HDMI Test Pattern Project - Urbana Board Constraints
## RealDigital Urbana Board - XC7S50-CSGA324
## =============================================================================

## =============================================================================
## Clock - 100 MHz oscillator
## =============================================================================
set_property PACKAGE_PIN N15 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports clk_100mhz]

## =============================================================================
## Reset Button - BTN0
## =============================================================================
set_property PACKAGE_PIN J2 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS25 [get_ports reset_btn]

## =============================================================================
## Slide Switches - SW0-SW15 (directly active high)
## =============================================================================
set_property PACKAGE_PIN G1 [get_ports {SW[0]}]
set_property PACKAGE_PIN F2 [get_ports {SW[1]}]
set_property PACKAGE_PIN F1 [get_ports {SW[2]}]
set_property PACKAGE_PIN E2 [get_ports {SW[3]}]
set_property PACKAGE_PIN E1 [get_ports {SW[4]}]
set_property PACKAGE_PIN D2 [get_ports {SW[5]}]
set_property PACKAGE_PIN D1 [get_ports {SW[6]}]
set_property PACKAGE_PIN C2 [get_ports {SW[7]}]
set_property PACKAGE_PIN B2 [get_ports {SW[8]}]
set_property PACKAGE_PIN A4 [get_ports {SW[9]}]
set_property PACKAGE_PIN A5 [get_ports {SW[10]}]
set_property PACKAGE_PIN A6 [get_ports {SW[11]}]
set_property PACKAGE_PIN C7 [get_ports {SW[12]}]
set_property PACKAGE_PIN A7 [get_ports {SW[13]}]
set_property PACKAGE_PIN B7 [get_ports {SW[14]}]
set_property PACKAGE_PIN A8 [get_ports {SW[15]}]

set_property IOSTANDARD LVCMOS25 [get_ports {SW[*]}]

## =============================================================================
## LEDs - Using only LED[0-7] for now (verified pins)
## =============================================================================
set_property PACKAGE_PIN E18 [get_ports {LED[0]}]
set_property PACKAGE_PIN F13 [get_ports {LED[1]}]
set_property PACKAGE_PIN E13 [get_ports {LED[2]}]
set_property PACKAGE_PIN H15 [get_ports {LED[3]}]
set_property PACKAGE_PIN J15 [get_ports {LED[4]}]
set_property PACKAGE_PIN G17 [get_ports {LED[5]}]
set_property PACKAGE_PIN F15 [get_ports {LED[6]}]
set_property PACKAGE_PIN E15 [get_ports {LED[7]}]

set_property IOSTANDARD LVCMOS33 [get_ports {LED[*]}]

## =============================================================================
## HDMI Output (TMDS Differential Signaling)
## Verified from mb_usb_hdmi_top.xdc reference
## =============================================================================
## HDMI Clock
set_property -dict {PACKAGE_PIN U16 IOSTANDARD TMDS_33} [get_ports hdmi_clk_p]
set_property -dict {PACKAGE_PIN V17 IOSTANDARD TMDS_33} [get_ports hdmi_clk_n]

## HDMI Data Channel 0
set_property -dict {PACKAGE_PIN U17 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[0]}]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[0]}]

## HDMI Data Channel 1
set_property -dict {PACKAGE_PIN R16 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[1]}]
set_property -dict {PACKAGE_PIN R17 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[1]}]

## HDMI Data Channel 2
set_property -dict {PACKAGE_PIN R14 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_p[2]}]
set_property -dict {PACKAGE_PIN T14 IOSTANDARD TMDS_33} [get_ports {hdmi_tx_n[2]}]

## =============================================================================
## Configuration
## =============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
