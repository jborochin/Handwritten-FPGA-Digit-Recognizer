# ==============================================================================
# USB Mouse Test Project - CORRECTED Constraints File
# Target: RealDigital Urbana Board (Spartan-7 XC7S50)
# Based on official Urbana Board constraints V2I1
# ==============================================================================

# System Clock - 100 MHz oscillator on Urbana Board
set_property -dict {PACKAGE_PIN N15 IOSTANDARD LVCMOS33} [get_ports sys_clock]
create_clock -period 10.000 -name sys_clk [get_ports sys_clock]

# ==============================================================================
# MAX3421E USB Host Controller - SPI Interface (ACTIVE LOW DIRECTLY TO PINS)
# ==============================================================================
# These are the OFFICIAL pin assignments from Urbana Board constraints file

# SPI MISO (Master In Slave Out - directly connected)
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports spi_miso]

# SPI MOSI (Master Out Slave In - directly connected) 
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports spi_mosi]

# SPI Clock (directly connected)
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports spi_sck]

# SPI Slave Select (active low - directly connected)
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports {spi_ss[0]}]

# ==============================================================================
# MAX3421E Control Signals (directly connected)
# ==============================================================================
# Reset to MAX3421E (active low - directly connected)
set_property -dict {PACKAGE_PIN V13 IOSTANDARD LVCMOS33} [get_ports {usb_rst_n[0]}]

# Interrupt from MAX3421E (directly connected input)
set_property -dict {PACKAGE_PIN T13 IOSTANDARD LVCMOS33} [get_ports {usb_int_n[0]}]

# Note: GPX signal is not broken out on the Urbana Board
# We'll use a dummy/unconnected signal or tie to a spare GPIO if needed

# ==============================================================================
# UART Debug Interface (directly connected)
# ==============================================================================
# UART on Urbana Board (directly connected to FTDI chip)
set_property -dict {PACKAGE_PIN A16 IOSTANDARD LVCMOS33} [get_ports uart_tx]
set_property -dict {PACKAGE_PIN B16 IOSTANDARD LVCMOS33} [get_ports uart_rx]

# ==============================================================================
# Debug LEDs (optional - directly connected)
# ==============================================================================
# Uncomment to use LEDs for debugging
# set_property -dict {PACKAGE_PIN C13 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
# set_property -dict {PACKAGE_PIN C14 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
# set_property -dict {PACKAGE_PIN D14 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
# set_property -dict {PACKAGE_PIN D15 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# ==============================================================================
# Timing Constraints
# ==============================================================================

# False paths for async inputs (directly connected)
set_false_path -from [get_ports {usb_int_n[0]}]
set_false_path -from [get_ports reset_n]

# NOTE: Do NOT use IOB constraints on SPI signals - they go through AXI SPI IP
# which handles its own I/O timing

# ==============================================================================
# Configuration Options
# ==============================================================================
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
