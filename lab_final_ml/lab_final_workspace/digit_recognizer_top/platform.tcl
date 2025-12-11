# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct C:\Users\vorte\ECE385\fpga_final_project\lab_final_ml\lab_final_workspace\digit_recognizer_top\platform.tcl
# 
# OR launch xsct and run below command.
# source C:\Users\vorte\ECE385\fpga_final_project\lab_final_ml\lab_final_workspace\digit_recognizer_top\platform.tcl
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {digit_recognizer_top}\
-hw {C:\Users\vorte\ECE385\fpga_final_project\lab_final_ml\digit_recognizer_top.xsa}\
-out {C:/Users/vorte/ECE385/fpga_final_project/lab_final_ml/lab_final_workspace}

platform write
domain create -name {standalone_microblaze_0} -display-name {standalone_microblaze_0} -os {standalone} -proc {microblaze_0} -runtime {cpp} -arch {32-bit} -support-app {hello_world}
platform generate -domains 
platform active {digit_recognizer_top}
platform generate -quick
platform clean
platform generate
