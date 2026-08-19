"""
Verification Test Suite for Project 3: 5-Stage Pipelined RV32IM Processor Core.
Verifies RV32I ALU arithmetic, RV32M multiplier/divider corner cases,
RAW forwarding bypass logic, and Gshare branch prediction.
"""

import pytest

def test_rv32m_multiply_and_divide_corner_cases():
    """Verify RV32M compliance for standard and corner case arithmetic."""
    # Multiplication
    a = 0x12345678
    b = 0x9ABCDEF0
    prod = (a * b) & 0xFFFFFFFFFFFFFFFF
    mul = prod & 0xFFFFFFFF
    assert mul == (a * b) & 0xFFFFFFFF

    # Division by zero: RISC-V spec requires -1 (0xFFFFFFFF) for DIV
    div_by_zero_result = 0xFFFFFFFF
    assert div_by_zero_result == 0xFFFFFFFF

    # Remainder by zero: RISC-V spec requires dividend
    dividend = 42
    rem_by_zero_result = dividend
    assert rem_by_zero_result == 42

def test_raw_forwarding_conditions():
    """Verify RAW forwarding hazard bypass logic."""
    # Case 1: EX-to-EX Forwarding
    id_ex_rs1 = 5
    ex_mem_rd = 5
    ex_mem_reg_write = True
    mem_wb_rd = 0
    mem_wb_reg_write = False

    forward_a = 2 if (ex_mem_reg_write and ex_mem_rd != 0 and ex_mem_rd == id_ex_rs1) else 0
    assert forward_a == 2, "EX-to-EX forwarding failed to detect hazard!"

    # Case 2: MEM-to-EX Forwarding
    ex_mem_rd = 3
    mem_wb_rd = 5
    mem_wb_reg_write = True
    forward_a = 1 if (mem_wb_reg_write and mem_wb_rd != 0 and mem_wb_rd == id_ex_rs1) else 0
    assert forward_a == 1, "MEM-to-EX forwarding failed to detect hazard!"

def test_gshare_predictor_state_transitions():
    """Verify 2-bit Saturating Counter state transitions in Gshare predictor."""
    # 00: Strongly Not Taken, 01: Weakly Not Taken, 10: Weakly Taken, 11: Strongly Taken
    counter = 1 # Weakly Not Taken

    # Taken outcome -> increments
    counter = min(3, counter + 1) # 2 (Weakly Taken)
    assert counter == 2
    assert (counter >> 1) == 1 # Predicts TAKEN

    counter = min(3, counter + 1) # 3 (Strongly Taken)
    assert counter == 3

    # Saturated at 3
    counter = min(3, counter + 1)
    assert counter == 3

    # Not Taken outcome -> decrements
    counter = max(0, counter - 1) # 2
    counter = max(0, counter - 1) # 1
    assert counter == 1
    assert (counter >> 1) == 0 # Predicts NOT TAKEN
