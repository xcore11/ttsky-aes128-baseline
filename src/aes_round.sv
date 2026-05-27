`timescale 1ns/1ps

/*
 * ============================================================
 * File        : aes_round.sv
 * Description : AES-128 round transformation
 *
 * Function:
 *   Performs one AES encryption round by connecting the main AES
 *   round operations together.
 *
 * Normal AES round:
 *   SubBytes -> ShiftRows -> MixColumns -> AddRoundKey
 *
 * Final AES round:
 *   SubBytes -> ShiftRows -> AddRoundKey
 *
 * final_round:
 *   0 = normal round, includes MixColumns
 *   1 = final round, skips MixColumns
 *
 * Notes:
 *   - This module is purely combinational.
 *   - It does not store the AES state.
 *   - The AES state register is stored in aes_core_baseline.sv.
 *   - MixColumns is always instantiated in the baseline design,
 *     but its output is ignored during the final round.
 * ============================================================
 */

module aes_round
(
    input  logic [127:0] state_in,
    input  logic [127:0] round_key,
    input  logic         final_round,
    output logic [127:0] state_out
);

    /*
     * Intermediate signal after SubBytes.
     *
     * SubBytes substitutes each byte of the AES state using the
     * AES S-box.
     */
    logic [127:0] sub_bytes_out;

    /*
     * Intermediate signal after ShiftRows.
     *
     * ShiftRows rearranges the bytes of the AES state according
     * to the AES row-shifting rule.
     */
    logic [127:0] shift_rows_out;

    /*
     * Intermediate signal after MixColumns.
     *
     * MixColumns mixes each AES column using finite-field
     * arithmetic. This signal is used for rounds 1 to 9.
     */
    logic [127:0] mix_columns_out;

    /*
     * Selected input to AddRoundKey.
     *
     * For rounds 1 to 9:
     *   add_roundkey_in = mix_columns_out
     *
     * For final round 10:
     *   add_roundkey_in = shift_rows_out
     *
     * This is how the final AES round skips MixColumns.
     */
    logic [127:0] add_roundkey_in;

    /*
     * SubBytes.
     *
     * Applies the S-box to all 16 bytes of the state. In the
     * baseline design, this is done using parallel S-box instances
     * inside the sub_bytes module.
     */
    sub_bytes u_sub_bytes
    (
        .state_in  (state_in),
        .state_out (sub_bytes_out)
    );

    /*
     * ShiftRows.
     *
     * Rearranges the output of SubBytes by shifting each AES state
     * row by a different offset.
     */
    shift_rows u_shift_rows
    (
        .state_in  (sub_bytes_out),
        .state_out (shift_rows_out)
    );

    /*
     * MixColumns.
     *
     * Applies the AES MixColumns operation to all four columns.
     * Although this block is instantiated for every round, the
     * final-round multiplexer below ignores this output when
     * final_round is high.
     */
    mix_columns u_mix_columns
    (
        .state_in  (shift_rows_out),
        .state_out (mix_columns_out)
    );

    /*
     * Final-round selection.
     *
     * AES rounds 1 to 9 include MixColumns.
     * AES round 10 skips MixColumns.
     */
    assign add_roundkey_in = final_round ? shift_rows_out : mix_columns_out;

    /*
     * AddRoundKey.
     *
     * XORs the selected AES state with the round key.
     */
    add_roundkey u_add_roundkey
    (
        .state_in  (add_roundkey_in),
        .round_key (round_key),
        .state_out (state_out)
    );

endmodule