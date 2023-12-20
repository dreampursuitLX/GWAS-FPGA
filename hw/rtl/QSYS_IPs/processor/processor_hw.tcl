package require -exact qsys 17.1


# 
# module processor
# 
set_module_property DESCRIPTION "processor"
set_module_property NAME processor
set_module_property VERSION 1.0
set_module_property INTERNAL false
set_module_property AUTHOR ""
set_module_property DISPLAY_NAME processor
set_module_property INSTANTIATE_IN_SYSTEM_MODULE true
set_module_property EDITABLE true


# 
# file sets
# 
add_fileset QUARTUS_SYNTH QUARTUS_SYNTH "" ""
set_fileset_property QUARTUS_SYNTH TOP_LEVEL processor
set_fileset_property QUARTUS_SYNTH ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property QUARTUS_SYNTH ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file processor.v VERILOG PATH processor.v TOP_LEVEL_FILE

add_fileset SIM_VERILOG SIM_VERILOG "" ""
set_fileset_property SIM_VERILOG TOP_LEVEL processor 
set_fileset_property SIM_VERILOG ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VERILOG ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file processor.v VERILOG PATH processor.v

add_fileset SIM_VHDL SIM_VHDL "" ""
set_fileset_property SIM_VHDL TOP_LEVEL processor
set_fileset_property SIM_VHDL ENABLE_RELATIVE_INCLUDE_PATHS false
set_fileset_property SIM_VHDL ENABLE_FILE_OVERWRITE_MODE false
add_fileset_file processor.v VERILOG PATH processor.v

set_module_property VALIDATION_CALLBACK     validate_me


# 
# parameters
# 
add_parameter DATA_WIDTH INTEGER 32
set_parameter_property DATA_WIDTH DEFAULT_VALUE 32
set_parameter_property DATA_WIDTH DISPLAY_NAME "Data Width"
set_parameter_property DATA_WIDTH UNITS None
set_parameter_property DATA_WIDTH DESCRIPTION "Data width specifies the width of the pattern slave and streaming ports"
set_parameter_property DATA_WIDTH ALLOWED_RANGES {32 64 128 256 512 1024}
set_parameter_property DATA_WIDTH DISPLAY_HINT ""
set_parameter_property DATA_WIDTH AFFECTS_GENERATION false
set_parameter_property DATA_WIDTH HDL_PARAMETER true

add_parameter EMPTY_WIDTH INTEGER 4
set_parameter_property EMPTY_WIDTH DEFAULT_VALUE 4
set_parameter_property EMPTY_WIDTH DISPLAY_NAME EMPTY_WIDTH
set_parameter_property EMPTY_WIDTH UNITS None
set_parameter_property EMPTY_WIDTH VISIBLE false
set_parameter_property EMPTY_WIDTH DERIVED true
set_parameter_property EMPTY_WIDTH DISPLAY_HINT ""
set_parameter_property EMPTY_WIDTH AFFECTS_GENERATION false
set_parameter_property EMPTY_WIDTH HDL_PARAMETER true

# 
# display items
# 


# 
# connection point clock
# 
add_interface clock clock end
set_interface_property clock clockRate 0
set_interface_property clock ENABLED true
set_interface_property clock EXPORT_OF ""
set_interface_property clock PORT_NAME_MAP ""
set_interface_property clock CMSIS_SVD_VARIABLES ""
set_interface_property clock SVD_ADDRESS_GROUP ""

add_interface_port clock clk clk Input 1


# 
# connection point reset
# 
add_interface reset reset end
set_interface_property reset associatedClock clock
set_interface_property reset synchronousEdges BOTH
set_interface_property reset ENABLED true
set_interface_property reset EXPORT_OF ""
set_interface_property reset PORT_NAME_MAP ""
set_interface_property reset CMSIS_SVD_VARIABLES ""
set_interface_property reset SVD_ADDRESS_GROUP ""

add_interface_port reset reset reset Input 1


# 
# connection point csr
# 
add_interface csr avalon end
set_interface_property csr addressAlignment DYNAMIC
set_interface_property csr associatedClock clock
set_interface_property csr associatedReset reset
set_interface_property csr burstOnBurstBoundariesOnly false
set_interface_property csr explicitAddressSpan 0
set_interface_property csr holdTime 0
set_interface_property csr isMemoryDevice false
set_interface_property csr isNonVolatileStorage false
set_interface_property csr linewrapBursts false
set_interface_property csr maximumPendingReadTransactions 0
set_interface_property csr printableDevice false
set_interface_property csr readLatency 1
set_interface_property csr readWaitTime 0
set_interface_property csr setupTime 0
set_interface_property csr timingUnits Cycles
set_interface_property csr writeWaitTime 0

set_interface_property csr ENABLED true

add_interface_port csr csr_address address Input 2
add_interface_port csr csr_writedata writedata Input 32
add_interface_port csr csr_write write Input 1
add_interface_port csr csr_readdata readdata Output 32
add_interface_port csr csr_read read Input 1
add_interface_port csr csr_byteenable byteenable Input 4
set_interface_assignment csr embeddedsw.configuration.isFlash 0
set_interface_assignment csr embeddedsw.configuration.isMemoryDevice 0
set_interface_assignment csr embeddedsw.configuration.isNonVolatileStorage 0
set_interface_assignment csr embeddedsw.configuration.isPrintableDevice 0



# +-----------------------------------
# | connection point query_input
# | 
add_interface query_input avalon_streaming end
set_interface_property query_input associatedClock clock
set_interface_property query_input associatedReset reset
set_interface_property query_input dataBitsPerSymbol 8
set_interface_property query_input errorDescriptor ""
set_interface_property query_input maxChannel 0
set_interface_property query_input readyLatency 0

set_interface_property query_input ENABLED true

add_interface_port query_input q_data data Input DATA_WIDTH
add_interface_port query_input q_valid valid Input 1
add_interface_port query_input q_ready ready Output 1
add_interface_port query_input q_empty empty Input EMPTY_WIDTH
add_interface_port query_input q_sop startofpacket Input 1
add_interface_port query_input q_eop endofpacket Input 1


# +-----------------------------------
# | connection point ref_input
# | 
add_interface ref_input avalon_streaming end
set_interface_property ref_input associatedClock clock
set_interface_property ref_input associatedReset reset
set_interface_property ref_input dataBitsPerSymbol 8
set_interface_property ref_input errorDescriptor ""
set_interface_property ref_input maxChannel 0
set_interface_property ref_input readyLatency 0

set_interface_property ref_input ENABLED true

add_interface_port ref_input r_data data Input DATA_WIDTH
add_interface_port ref_input r_valid valid Input 1
add_interface_port ref_input r_ready ready Output 1
add_interface_port ref_input r_empty empty Input EMPTY_WIDTH
add_interface_port ref_input r_sop startofpacket Input 1
add_interface_port ref_input r_eop endofpacket Input 1
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point st_pattern_output
# | 
add_interface st_pattern_output avalon_streaming start
set_interface_property st_pattern_output associatedClock clock
set_interface_property st_pattern_output associatedReset reset
set_interface_property st_pattern_output dataBitsPerSymbol 8
set_interface_property st_pattern_output errorDescriptor ""
set_interface_property st_pattern_output maxChannel 0
set_interface_property st_pattern_output readyLatency 3

set_interface_property st_pattern_output ENABLED true

add_interface_port st_pattern_output src_data data Output DATA_WIDTH
add_interface_port st_pattern_output src_valid valid Output 1
add_interface_port st_pattern_output src_ready ready Input 1
add_interface_port st_pattern_output src_empty empty Output EMPTY_WIDTH
add_interface_port st_pattern_output src_sop startofpacket Output 1
add_interface_port st_pattern_output src_eop endofpacket Output 1
# | 
# +-----------------------------------

# +-----------------------------------
# | connection point csr_irq
# | 
add_interface irq interrupt end
set_interface_property irq associatedAddressablePoint csr

set_interface_property irq ASSOCIATED_CLOCK clock

add_interface_port irq irq irq Output 1
# | 
# +-----------------------------------


# need to set address width based on log2(MAX_PATTERN_LENGTH) which is already a power of 2
proc validate_me {}  {

set_parameter_value EMPTY_WIDTH [expr {(log([get_parameter_value DATA_WIDTH] / 8)) / (log (2))}]

}

