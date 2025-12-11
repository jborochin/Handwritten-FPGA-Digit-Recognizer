//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
//Date        : Mon Dec  8 12:14:28 2025
//Host        : SirJason running 64-bit major release  (build 9200)
//Command     : generate_target usb_mouse_system_wrapper.bd
//Design      : usb_mouse_system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module usb_mouse_system_wrapper
   (spi_miso,
    spi_mosi,
    spi_sck,
    spi_ss,
    sys_clock,
    uart_rx,
    uart_tx,
    usb_int_n,
    usb_rst_n);
  input spi_miso;
  output spi_mosi;
  output spi_sck;
  output [0:0]spi_ss;
  input sys_clock;
  input uart_rx;
  output uart_tx;
  input [0:0]usb_int_n;
  output [0:0]usb_rst_n;

  wire spi_miso;
  wire spi_mosi;
  wire spi_sck;
  wire [0:0]spi_ss;
  wire sys_clock;
  wire uart_rx;
  wire uart_tx;
  wire [0:0]usb_int_n;
  wire [0:0]usb_rst_n;

  usb_mouse_system usb_mouse_system_i
       (.spi_miso(spi_miso),
        .spi_mosi(spi_mosi),
        .spi_sck(spi_sck),
        .spi_ss(spi_ss),
        .sys_clock(sys_clock),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .usb_int_n(usb_int_n),
        .usb_rst_n(usb_rst_n));
endmodule
