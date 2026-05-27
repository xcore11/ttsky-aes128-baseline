`timescale 1ns/1ps

/*
 * ============================================================
 * File        : mix_columns.sv
 * Description : AES-128 MixColumns transformation
 *
 * Function:
 *   Performs the AES MixColumns operation on the 128-bit AES
 *   state.
 *
 * Structure:
 *   - mix_columns_one_column:
 *       Performs MixColumns on one 32-bit column.
 *   - mix_columns:
 *       Instantiates four mix_columns_one_column blocks to process
 *       all four AES columns in parallel.
 *
 * AES state ordering used in this design:
 *
 *   state[127:96] = column 0 = {b0,  b1,  b2,  b3}
 *   state[95:64]  = column 1 = {b4,  b5,  b6,  b7}
 *   state[63:32]  = column 2 = {b8,  b9,  b10, b11}
 *   state[31:0]   = column 3 = {b12, b13, b14, b15}
 *
 * Baseline design choice:
 *   - This baseline version uses four parallel MixColumns column
 *     units.
 *   - All four columns are processed combinationally in the same
 *     AES round.
 *   - This supports the iterative one-round-per-cycle architecture.
 *
 * Optimization comparison:
 *   - In the later area-optimized version, only one
 *     mix_columns_one_column block can be reused across four
 *     cycles to reduce hardware area.
 *   - That optimized version will save area but increase cycle
 *     count and controller complexity.
 * ============================================================
 */


/*
 * ============================================================
 * Module      : mix_columns_one_column
 * Description : AES MixColumns operation for one 32-bit column
 *
 * Input column:
 *   col_in = {s0, s1, s2, s3}
 *
 * Output column:
 *   col_out = {m0, m1, m2, m3}
 *
 * AES MixColumns equations:
 *
 *   m0 = 02*s0 XOR 03*s1 XOR 01*s2 XOR 01*s3
 *   m1 = 01*s0 XOR 02*s1 XOR 03*s2 XOR 01*s3
 *   m2 = 01*s0 XOR 01*s1 XOR 02*s2 XOR 03*s3
 *   m3 = 03*s0 XOR 01*s1 XOR 01*s2 XOR 02*s3
 *
 * In AES GF(2^8):
 *   02*x = xtime(x)
 *   03*x = xtime(x) XOR x
 *
 * Hardware meaning:
 *   - This module is purely combinational.
 *   - It contains no clocked logic or registers.
 *   - It uses XOR logic and xtime logic to implement AES finite
 *     field multiplication.
 * ============================================================
 */

module mix_columns_one_column
(
	 // AES state before MixColumns per column.
    input  logic [31:0] col_in,
	 
	 // AES state after MixColumns per column.
    output logic [31:0] col_out
);

    /*
     * Split the 32-bit input column into four AES state bytes.
     *
     * col_in = {s0, s1, s2, s3}
     */
    logic [7:0] s0;
    logic [7:0] s1;
    logic [7:0] s2;
    logic [7:0] s3;

    /*
     * xtime results.
     *
     * xi represents multiplication of si by 02 in AES GF(2^8).
     */
    logic [7:0] x0;
    logic [7:0] x1;
    logic [7:0] x2;
    logic [7:0] x3;

    // Output bytes after MixColumns.
    logic [7:0] m0;
    logic [7:0] m1;
    logic [7:0] m2;
    logic [7:0] m3;

    // Byte extraction from input column.
    assign s0 = col_in[31:24];
    assign s1 = col_in[23:16];
    assign s2 = col_in[15:8];
    assign s3 = col_in[7:0];

    /*
     * Precompute multiplication by 02.
     *
     * This avoids repeating aes_xtime() multiple times in the
     * equations below.
     */
    assign x0 = aes_xtime(s0);
    assign x1 = aes_xtime(s1);
    assign x2 = aes_xtime(s2);
    assign x3 = aes_xtime(s3);

    /*
     * MixColumns equations.
     *
     * Multiplication by 03 is implemented as:
     *
     *   03*x = 02*x XOR x
     *        = xtime(x) XOR x
     */
    assign m0 = x0 ^ (x1 ^ s1) ^ s2 ^ s3;
    assign m1 = s0 ^ x1 ^ (x2 ^ s2) ^ s3;
    assign m2 = s0 ^ s1 ^ x2 ^ (x3 ^ s3);
    assign m3 = (x0 ^ s0) ^ s1 ^ s2 ^ x3;

    // Combine the four output bytes into one 32-bit column.
    assign col_out = {m0, m1, m2, m3};

    /*
     * Function    : aes_xtime
     * Description : Multiplication by 02 in AES GF(2^8)
     *
     * GF(2^8) rule:
     *   If the most significant bit is 0:
     *       result = b << 1
     *
     *   If the most significant bit is 1:
     *       result = (b << 1) XOR 8'h1b
     *
     * The value 8'h1b represents reduction by the AES
     * irreducible polynomial:
     *
     *   x^8 + x^4 + x^3 + x + 1
     */
    function automatic logic [7:0] aes_xtime
    (
        input logic [7:0] b
    );
        begin
            if (b[7] == 1'b1) begin
                aes_xtime = (b << 1) ^ 8'h1b;
            end
            else begin
                aes_xtime = (b << 1);
            end
        end
    endfunction

endmodule


/*
 * ============================================================
 * Module      : mix_columns
 * Description : Full AES MixColumns transformation
 *
 * Function:
 *   Applies MixColumns to all four columns of the AES state.
 *
 * Baseline architecture:
 *   - Four mix_columns_one_column modules are instantiated.
 *   - All four columns are processed in parallel.
 *   - This supports one AES round per clock cycle.
 *
 * State mapping:
 *
 *   state_in[127:96] -> column 0
 *   state_in[95:64]  -> column 1
 *   state_in[63:32]  -> column 2
 *   state_in[31:0]   -> column 3
 * ============================================================
 */

module mix_columns
(
	 // AES state before MixColumns.
    input  logic [127:0] state_in,
	 
	 // AES state before MixColumns.
    output logic [127:0] state_out
);

    // Column 0 MixColumns operation.
	 
    mix_columns_one_column u_col0
    (
        .col_in  (state_in[127:96]),
        .col_out (state_out[127:96])
    );

    // Column 1 MixColumns operation.
	 
    mix_columns_one_column u_col1
    (
        .col_in  (state_in[95:64]),
        .col_out (state_out[95:64])
    );

    // Column 2 MixColumns operation.
	 
    mix_columns_one_column u_col2
    (
        .col_in  (state_in[63:32]),
        .col_out (state_out[63:32])
    );

    // Column 3 MixColumns operation.
	 
    mix_columns_one_column u_col3
    (
        .col_in  (state_in[31:0]),
        .col_out (state_out[31:0])
    );

endmodule