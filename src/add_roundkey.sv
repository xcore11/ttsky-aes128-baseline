`timescale 1ns/1ps

/*
 * ============================================================
 * File        : add_roundkey.sv
 * Description : AES-128 AddRoundKey transformation
 *
 * Function:
 *   Performs the AES AddRoundKey operation by XORing the current
 *   128-bit AES state with the 128-bit round key.
 *
 * AES operation:
 *
 *   state_out = state_in XOR round_key
 *
 * Role in AES-128:
 *   AddRoundKey is used:
 *     1. before round 1 as the initial AddRoundKey step
 *     2. at the end of each normal round, rounds 1 to 9
 *     3. at the end of the final round, round 10
 *
 * Hardware meaning:
 *   - This module is purely combinational.
 *   - It does not contain flip-flops, registers, FSM logic, or
 *     clocked behaviour.
 *   - Each bit of state_in is XORed with the corresponding bit
 *     of round_key.
 *   - In synthesis, this becomes simple 128-bit XOR logic.
 *
 * Reusability:
 *   - This module is used in the baseline one-round-per-cycle
 *     AES design.
 *   - It can also be reused in the later area-optimized design,
 *     because AddRoundKey is already a very small operation.
 * ============================================================
 */

module add_roundkey
(
    // Current AES state before AddRoundKey.
    input  logic [127:0] state_in,

    // Current AES round key.
    input  logic [127:0] round_key,

    // AES state after XORing with the round key.
    output logic [127:0] state_out
);

    /*
     * AddRoundKey operation.
     *
     * AES combines the current state with the current round key
     * using bitwise XOR.
     *
     * For each bit position i:
     *   state_out[i] = state_in[i] XOR round_key[i]
     */
    assign state_out = state_in ^ round_key;

endmodule