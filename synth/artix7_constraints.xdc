# Xilinx Design Constraints (XDC) for RV32IM Core on Artix-7
# Target Clock Frequency: 125 MHz (Period: 8.000 ns)

# Define Primary System Clock
create_clock -name sys_clk -period 8.000 [get_ports clk]

# Clock Uncertainty & Jitter Budget
set_clock_uncertainty 0.200 [get_clocks sys_clk]

# Input / Output Delay Constraints (assuming 20% setup budget for external AXI memory)
set_input_delay -clock [get_clocks sys_clk] -max 1.600 [get_ports {rst_n m_axi_imem_* m_axi_dmem_*}]
set_input_delay -clock [get_clocks sys_clk] -min 0.400 [get_ports {rst_n m_axi_imem_* m_axi_dmem_*}]

set_output_delay -clock [get_clocks sys_clk] -max 1.600 [get_ports {m_axi_imem_* m_axi_dmem_*}]
set_output_delay -clock [get_clocks sys_clk] -min 0.400 [get_ports {m_axi_imem_* m_axi_dmem_*}]
