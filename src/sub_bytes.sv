`timescale 1ns/1ps

/*
 * ============================================================
 * File        : sub_bytes.sv
 * Description : AES-128 SubBytes transformation
 *
 * Function:
 *   Applies the AES S-box independently to all 16 bytes of the
 *   128-bit AES state.
 *
 * AES operation:
 *   SubBytes replaces every byte in the AES state with another
 *   byte using the fixed AES S-box.
 *
 * Architecture:
 *   - Baseline implementation uses 16 parallel S-box instances.
 *   - This allows all 16 state bytes to be substituted in the
 *     same combinational round path.
 *   - This is suitable for the iterative one-round-per-cycle
 *     baseline AES design.
 *
 * Hardware meaning:
 *   - This module is purely combinational.
 *   - It does not contain registers, clocks, or FSM logic.
 *   - Each byte of state_in is connected to one sbox instance.
 *   - The substituted bytes are combined into state_out.
 *
 * Design comparison:
 *   - Baseline version:
 *       uses 16 parallel S-boxes for faster one-round-per-cycle
 *       operation.
 *   - Later area-optimized version:
 *       may reuse fewer S-box instances across multiple cycles
 *       to reduce area.
 *
 * Notes:
 *   - The actual S-box lookup table is implemented in sbox.sv.
 *   - This module only performs the 16-byte S-box connection.
 *   - The sbox module must be compiled before this file.
 * ============================================================
 */

module sub_bytes
(

    // AES state before SubBytes.
    input  logic [127:0] state_in,

    // AES state after SubBytes.
    output logic [127:0] state_out
);

    /*
     * Generate 16 parallel S-box instances.
     *
     * Each loop iteration processes one byte of the 128-bit AES
     * state.
     *
     * Byte selection:
     *   state_in[8*i +: 8]
     *
     * means:
     *   i = 0  -> state_in[7:0]
     *   i = 1  -> state_in[15:8]
     *   ...
     *   i = 15 -> state_in[127:120]
     *
     * The same byte position is preserved in state_out.
     */
    genvar i;

    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_sbox
            sbox u_sbox
            (
                .in_byte  (state_in [8*i +: 8]),
                .out_byte (state_out[8*i +: 8])
            );
        end
    endgenerate

endmodule