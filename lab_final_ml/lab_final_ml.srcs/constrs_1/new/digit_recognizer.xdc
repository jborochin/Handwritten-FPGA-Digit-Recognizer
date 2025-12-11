## =============================================================================
## Digit Recognizer with USB Mouse - Urbana Board Constraints
## RealDigital Urbana Board - XC7S50-CSGA324
## Based on working lab 6.2 pin assignments
## =============================================================================

## =============================================================================
## Clock - 100 MHz oscillator
## =============================================================================
set_property PACKAGE_PIN N15 [get_ports clk_100mhz]
set_property IOSTANDARD LVCMOS33 [get_ports clk_100mhz]
create_clock -period 10.000 -name sys_clk_100 -waveform {0.000 5.000} [get_ports clk_100mhz]

## =============================================================================
## Reset Button
## =============================================================================
set_property PACKAGE_PIN J2 [get_ports reset_btn]
set_property IOSTANDARD LVCMOS25 [get_ports reset_btn]

## =============================================================================
## USB Host (MAX3421E) - From lab 6.2
## =============================================================================
## USB SPI Interface
set_property PACKAGE_PIN U12 [get_ports usb_spi_miso]
set_property PACKAGE_PIN V15 [get_ports usb_spi_mosi]
set_property PACKAGE_PIN V14 [get_ports usb_spi_sclk]
set_property PACKAGE_PIN T12 [get_ports usb_spi_ss]
set_property IOSTANDARD LVCMOS33 [get_ports usb_spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports usb_spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports usb_spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports usb_spi_ss]

## USB Interrupt
set_property PACKAGE_PIN T13 [get_ports {gpio_usb_int_tri_i[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {gpio_usb_int_tri_i[0]}]

## USB Reset
set_property PACKAGE_PIN V13 [get_ports gpio_usb_rst_tri_o]
set_property IOSTANDARD LVCMOS33 [get_ports gpio_usb_rst_tri_o]

## =============================================================================
## UART - From lab 6.2
## =============================================================================
set_property PACKAGE_PIN B16 [get_ports uart_rtl_0_rxd]
set_property PACKAGE_PIN A16 [get_ports uart_rtl_0_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_0_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rtl_0_txd]

## =============================================================================
## HDMI Output (TMDS Differential Signaling)
## =============================================================================
## HDMI Clock
set_property PACKAGE_PIN U16 [get_ports hdmi_clk_p]
set_property PACKAGE_PIN V17 [get_ports hdmi_clk_n]
set_property IOSTANDARD TMDS_33 [get_ports hdmi_clk_p]
set_property IOSTANDARD TMDS_33 [get_ports hdmi_clk_n]

## HDMI Data Channels
set_property PACKAGE_PIN U17 [get_ports {hdmi_data_p[0]}]
set_property PACKAGE_PIN U18 [get_ports {hdmi_data_n[0]}]
set_property PACKAGE_PIN R16 [get_ports {hdmi_data_p[1]}]
set_property PACKAGE_PIN R17 [get_ports {hdmi_data_n[1]}]
set_property PACKAGE_PIN R14 [get_ports {hdmi_data_p[2]}]
set_property PACKAGE_PIN T14 [get_ports {hdmi_data_n[2]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_data_p[*]}]
set_property IOSTANDARD TMDS_33 [get_ports {hdmi_data_n[*]}]

## =============================================================================
## LEDs (only LED[0:7] - others have invalid pins on this package)
## =============================================================================
set_property PACKAGE_PIN E18 [get_ports {led[0]}]
set_property PACKAGE_PIN F13 [get_ports {led[1]}]
set_property PACKAGE_PIN E13 [get_ports {led[2]}]
set_property PACKAGE_PIN H15 [get_ports {led[3]}]
set_property PACKAGE_PIN J15 [get_ports {led[4]}]
set_property PACKAGE_PIN G17 [get_ports {led[5]}]
set_property PACKAGE_PIN F15 [get_ports {led[6]}]
set_property PACKAGE_PIN E15 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[*]}]

## =============================================================================
## Seven Segment Display A - From lab 6.2
## =============================================================================
set_property PACKAGE_PIN E6 [get_ports {hex_segA[0]}]
set_property PACKAGE_PIN B4 [get_ports {hex_segA[1]}]
set_property PACKAGE_PIN D5 [get_ports {hex_segA[2]}]
set_property PACKAGE_PIN C5 [get_ports {hex_segA[3]}]
set_property PACKAGE_PIN D7 [get_ports {hex_segA[4]}]
set_property PACKAGE_PIN D6 [get_ports {hex_segA[5]}]
set_property PACKAGE_PIN C4 [get_ports {hex_segA[6]}]
set_property PACKAGE_PIN B5 [get_ports {hex_segA[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports {hex_segA[*]}]

set_property PACKAGE_PIN G6 [get_ports {hex_gridA[0]}]
set_property PACKAGE_PIN H6 [get_ports {hex_gridA[1]}]
set_property PACKAGE_PIN C3 [get_ports {hex_gridA[2]}]
set_property PACKAGE_PIN B3 [get_ports {hex_gridA[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {hex_gridA[*]}]

## =============================================================================
## Seven Segment Display B - From lab 6.2
## =============================================================================
set_property PACKAGE_PIN F3 [get_ports {hex_segB[0]}]
set_property PACKAGE_PIN G5 [get_ports {hex_segB[1]}]
set_property PACKAGE_PIN J3 [get_ports {hex_segB[2]}]
set_property PACKAGE_PIN H4 [get_ports {hex_segB[3]}]
set_property PACKAGE_PIN F4 [get_ports {hex_segB[4]}]
set_property PACKAGE_PIN H3 [get_ports {hex_segB[5]}]
set_property PACKAGE_PIN E5 [get_ports {hex_segB[6]}]
set_property PACKAGE_PIN J4 [get_ports {hex_segB[7]}]
set_property IOSTANDARD LVCMOS25 [get_ports {hex_segB[*]}]

set_property PACKAGE_PIN E4 [get_ports {hex_gridB[0]}]
set_property PACKAGE_PIN E3 [get_ports {hex_gridB[1]}]
set_property PACKAGE_PIN F5 [get_ports {hex_gridB[2]}]
set_property PACKAGE_PIN H5 [get_ports {hex_gridB[3]}]
set_property IOSTANDARD LVCMOS25 [get_ports {hex_gridB[*]}]

## =============================================================================
## Configuration
## =============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
