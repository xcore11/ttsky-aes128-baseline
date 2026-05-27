`timescale 1ns/1ps

/*
 * ============================================================
 * File        : key_expansion.sv
 * Description : AES-128 one-round key expansion
 *
 * Function:
 *   Generates the next 128-bit AES round key from the current
 *   128-bit round key and the current Rcon byte.
 *
 * Role in AES-128:
 *   AES-128 does not use the original secret key directly for
 *   every round. Instead, the original 128-bit key is expanded
 *   into 11 round keys:
 *
 *     K0  = original key, used in the initial AddRoundKey
 *     K1  = round 1 key
 *     K2  = round 2 key
 *     ...
 *     K10 = final round key
 *
 *   This module generates only one next round key at a time.
 *   Therefore, it is suitable for the iterative baseline design,
 *   where one new round key is generated during each AES round.
 *
 * AES-128 key schedule:
 *
 *   Current round key:
 *     key_in = {w0, w1, w2, w3}
 *
 *   Next round key:
 *     w4 = w0 XOR SubWord(RotWord(w3)) XOR Rcon
 *     w5 = w1 XOR w4
 *     w6 = w2 XOR w5
 *     w7 = w3 XOR w6
 *
 *   key_out = {w4, w5, w6, w7}
 *
 * AES operations used:
 *
 *   RotWord:
 *     Rotates the final 32-bit word left by one byte.
 *     Example:
 *       {a0, a1, a2, a3} -> {a1, a2, a3, a0}
 *
 *   SubWord:
 *     Applies the AES S-box to each byte of the rotated word.
 *
 *   Rcon:
 *     XORs the round constant into the most significant byte
 *     of the transformed word.
 *
 * Notes:
 *   - This module is purely combinational.
 *   - It does not contain registers or clocked logic.
 *   - The AES core stores key_out into round_key_reg at the
 *     appropriate clock edge.
 *   - The S-box module must be compiled before this file.
 * ============================================================
 */

module keyexpansion
(
    /*
     * Current 128-bit AES round key.
     *
     * For example:
     *   During round 1, key_in is K0.
     *   The module generates K1.
     */
    input  logic [127:0] key_in,

    /*
     * Current AES round constant.
     *
     * AES-128 Rcon sequence:
     *   01, 02, 04, 08, 10, 20, 40, 80, 1b, 36
     *
     * Only the most significant byte of g_word is XORed with
     * this value.
     */
    input  logic [7:0] rcon_byte,

    // Next 128-bit AES round key.
    output logic [127:0] key_out
);

    /*
     * Current key words.
     *
     * AES-128 views the 128-bit key as four 32-bit words:
     *
     *   key_in = {w0, w1, w2, w3}
     */
    logic [31:0] w0;
    logic [31:0] w1;
    logic [31:0] w2;
    logic [31:0] w3;

    /*
     * Newly generated key words.
     *
     * These four words form the next AES round key:
     *
     *   key_out = {w4, w5, w6, w7}
     */
    logic [31:0] w4;
    logic [31:0] w5;
    logic [31:0] w6;
    logic [31:0] w7;

    /*
     * Intermediate key schedule values.
     *
     * rot_word:
     *   result after RotWord(w3)
     *
     * sub_word:
     *   result after applying the S-box to each byte of rot_word
     *
     * g_word:
     *   result after applying Rcon to sub_word
     */
    logic [31:0] rot_word;
    logic [31:0] sub_word;
    logic [31:0] g_word;

    /*
     * Split key_in into four 32-bit words.
     *
     * The ordering follows the AES key schedule convention:
     *
     *   key_in[127:96] = w0
     *   key_in[95:64]  = w1
     *   key_in[63:32]  = w2
     *   key_in[31:0]   = w3
     */
    assign w0 = key_in[127:96];
    assign w1 = key_in[95:64];
    assign w2 = key_in[63:32];
    assign w3 = key_in[31:0];

    /*
     * RotWord
     *
     * Rotates w3 left by one byte.
     *
     * Example:
     *   w3       = {a0, a1, a2, a3}
     *   rot_word = {a1, a2, a3, a0}
     *
     * This prepares the word for S-box substitution.
     */
    assign rot_word = {w3[23:0], w3[31:24]};

    /*
     * SubWord
     *
     * Applies the AES S-box to each byte of rot_word.
     *
     * The same sbox module used by SubBytes is reused here.
     * This ensures the state datapath and key schedule use the
     * same substitution rule.
     */
    sbox u_key_sbox0
    (
        .in_byte  (rot_word[31:24]),
        .out_byte (sub_word[31:24])
    );

    sbox u_key_sbox1
    (
        .in_byte  (rot_word[23:16]),
        .out_byte (sub_word[23:16])
    );

    sbox u_key_sbox2
    (
        .in_byte  (rot_word[15:8]),
        .out_byte (sub_word[15:8])
    );

    sbox u_key_sbox3
    (
        .in_byte  (rot_word[7:0]),
        .out_byte (sub_word[7:0])
    );

    /*
     * Add Rcon
     *
     * Rcon is applied only to the most significant byte of
     * sub_word.
     *
     * Equivalent meaning:
     *
     *   g_word[31:24] = sub_word[31:24] XOR rcon_byte
     *   g_word[23:0]  = sub_word[23:0]
     */
    assign g_word = sub_word ^ {rcon_byte, 24'h000000};

    /*
     * Generate the next round key words.
     *
     * AES-128 key expansion uses XOR chaining:
     *
     *   w4 depends on w0 and g_word
     *   w5 depends on w1 and w4
     *   w6 depends on w2 and w5
     *   w7 depends on w3 and w6
     *
     * This means each newly generated word depends on the
     * previous newly generated word.
     */
    assign w4 = w0 ^ g_word;
    assign w5 = w1 ^ w4;
    assign w6 = w2 ^ w5;
    assign w7 = w3 ^ w6;

    // Combine the newly generated words into the next 128-bit round key.
    assign key_out = {w4, w5, w6, w7};

endmodule