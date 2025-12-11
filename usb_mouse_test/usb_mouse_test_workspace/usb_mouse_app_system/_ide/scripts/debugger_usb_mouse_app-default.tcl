# Usage with Vitis IDE:
# In Vitis IDE create a Single Application Debug launch configuration,
# change the debug type to 'Attach to running target' and provide this 
# tcl script in 'Execute Script' option.
# Path of this script: C:\Users\vorte\ECE385\fpga_final_project\usb_mouse_test\usb_mouse_test_workspace\usb_mouse_app_system\_ide\scripts\debugger_usb_mouse_app-default.tcl
# 
# 
# Usage with xsct:
# To debug using xsct, launch xsct and run below command
# source C:\Users\vorte\ECE385\fpga_final_project\usb_mouse_test\usb_mouse_test_workspace\usb_mouse_app_system\_ide\scripts\debugger_usb_mouse_app-default.tcl
# 
connect -url tcp:127.0.0.1:3121
targets -set -filter {jtag_cable_name =~ "RealDigital Boo 887100000004A" && level==0 && jtag_device_ctx=="jsn1-0362f093-0"}
fpga -file C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_test_workspace/usb_mouse_app/_ide/bitstream/usb_mouse_system_wrapper.bit
targets -set -nocase -filter {name =~ "*microblaze*#0" && bscan=="USER2" }
loadhw -hw C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_test_workspace/mouse_test_plat/export/mouse_test_plat/hw/usb_mouse_system_wrapper.xsa -regs
configparams mdm-detect-bscan-mask 2
targets -set -nocase -filter {name =~ "*microblaze*#0" && bscan=="USER2" }
rst -system
after 3000
targets -set -nocase -filter {name =~ "*microblaze*#0" && bscan=="USER2" }
dow C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_test_workspace/usb_mouse_app/Debug/usb_mouse_app.elf
targets -set -nocase -filter {name =~ "*microblaze*#0" && bscan=="USER2" }
con
