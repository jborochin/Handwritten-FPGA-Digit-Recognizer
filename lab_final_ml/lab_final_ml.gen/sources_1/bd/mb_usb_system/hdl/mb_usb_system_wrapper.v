//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.2 (win64) Build 3671981 Fri Oct 14 05:00:03 MDT 2022
//Date        : Sun Dec  7 16:35:35 2025
//Host        : SirJason running 64-bit major release  (build 9200)
//Command     : generate_target mb_usb_system_wrapper.bd
//Design      : mb_usb_system_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module mb_usb_system_wrapper
   (clk_100MHz,
    mouse_data_out,
    reset_rtl_0,
    rx_0,
    spi_rtl_0_io0_io,
    spi_rtl_0_io1_io,
    spi_rtl_0_ss_io,
    tx_0);
  input clk_100MHz;
  output [31:0]mouse_data_out;
  input reset_rtl_0;
  input rx_0;
  inout spi_rtl_0_io0_io;
  inout spi_rtl_0_io1_io;
  inout [0:0]spi_rtl_0_ss_io;
  output tx_0;

  wire clk_100MHz;
  wire [31:0]mouse_data_out;
  wire reset_rtl_0;
  wire rx_0;
  wire spi_rtl_0_io0_i;
  wire spi_rtl_0_io0_io;
  wire spi_rtl_0_io0_o;
  wire spi_rtl_0_io0_t;
  wire spi_rtl_0_io1_i;
  wire spi_rtl_0_io1_io;
  wire spi_rtl_0_io1_o;
  wire spi_rtl_0_io1_t;
  wire [0:0]spi_rtl_0_ss_i_0;
  wire [0:0]spi_rtl_0_ss_io_0;
  wire [0:0]spi_rtl_0_ss_o_0;
  wire spi_rtl_0_ss_t;
  wire tx_0;

  mb_usb_system mb_usb_system_i
       (.clk_100MHz(clk_100MHz),
        .mouse_data_out(mouse_data_out),
        .reset_rtl_0(reset_rtl_0),
        .rx_0(rx_0),
        .spi_rtl_0_io0_i(spi_rtl_0_io0_i),
        .spi_rtl_0_io0_o(spi_rtl_0_io0_o),
        .spi_rtl_0_io0_t(spi_rtl_0_io0_t),
        .spi_rtl_0_io1_i(spi_rtl_0_io1_i),
        .spi_rtl_0_io1_o(spi_rtl_0_io1_o),
        .spi_rtl_0_io1_t(spi_rtl_0_io1_t),
        .spi_rtl_0_ss_i(spi_rtl_0_ss_i_0),
        .spi_rtl_0_ss_o(spi_rtl_0_ss_o_0),
        .spi_rtl_0_ss_t(spi_rtl_0_ss_t),
        .tx_0(tx_0));
  IOBUF spi_rtl_0_io0_iobuf
       (.I(spi_rtl_0_io0_o),
        .IO(spi_rtl_0_io0_io),
        .O(spi_rtl_0_io0_i),
        .T(spi_rtl_0_io0_t));
  IOBUF spi_rtl_0_io1_iobuf
       (.I(spi_rtl_0_io1_o),
        .IO(spi_rtl_0_io1_io),
        .O(spi_rtl_0_io1_i),
        .T(spi_rtl_0_io1_t));
  IOBUF spi_rtl_0_ss_iobuf_0
       (.I(spi_rtl_0_ss_o_0),
        .IO(spi_rtl_0_ss_io[0]),
        .O(spi_rtl_0_ss_i_0),
        .T(spi_rtl_0_ss_t));
endmodule
