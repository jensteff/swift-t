
# Flex Turbine+ADLB but do nothing
# Nice to have for quick manual experiments

package require turbine 0.1
adlb_init 1
turbine_c_init

turbine_finalize
adlb_finalize
puts OK
