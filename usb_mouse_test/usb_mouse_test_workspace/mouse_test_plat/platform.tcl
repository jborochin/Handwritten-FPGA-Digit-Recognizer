# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Users\vorte\ECE385\fpga_final_project\usb_mouse_test\usb_mouse_test_workspace\mouse_test_plat\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Users\vorte\ECE385\fpga_final_project\usb_mouse_test\usb_mouse_test_workspace\mouse_test_plat\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {mouse_test_plat}\
-hw {C:\Users\vorte\ECE385\fpga_final_project\usb_mouse_test\mb_usb_wrapper.xsa}\
-proc {microblaze_0} -os {standalone} -out {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_test_workspace}

platform write
platform generate -domains 
platform active {mouse_test_plat}
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/mb_usb_wrapper.xsa}
platform generate -domains 
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_system_wrapper.xsa}
platform generate -domains 
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_system_wrapper.xsa}
platform generate -domains 
platform clean
platform generate
platform clean
platform generate
platform active {mouse_test_plat}
bsp reload
bsp write
platform generate -domains 
platform clean
platform generate
bsp reload
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_system_wrapper.xsa}
platform generate -domains 
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_system_wrapper.xsa}
platform clean
platform generate
platform clean
platform generate
platform config -updatehw {C:/Users/vorte/ECE385/fpga_final_project/usb_mouse_test/usb_mouse_system_wrapper.xsa}
platform generate -domains 
platform clean
platform generate
