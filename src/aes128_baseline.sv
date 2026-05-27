`timescale 1ns/1ps

/*
 * ============================================================
 * File        : aes128_baseline.sv
 * Description : AES-128 baseline top-level wrapper
 *
 * Project     : ECE4063 IC Design Project
 *
 * Architecture:
 *   - Baseline AES-128 encryption design.
 *   - Iterative one-round-per-cycle core.
 *   - Start / busy / done wrapper interface.
 *   - Lookup-table S-box implementation used inside the core.
 *
 * Function:
 *   This module is the external entry point of the baseline AES
 *   design. It does not perform AES encryption directly. Instead,
 *   it instantiates the AES core and exposes a simple control and
 *   data interface to the testbench, Quartus top-level entity, or
 *   later Tiny Tapeout wrapper.
 *
 * External interface:
 *   clk        : System clock.
 *   reset_n    : Active-low asynchronous reset.
 *   start      : One-clock pulse to request AES encryption.
 *   plaintext  : 128-bit input plaintext block.
 *   key        : 128-bit AES encryption key.
 *   ciphertext : 128-bit encrypted output block.
 *   busy       : High while AES encryption is running.
 *   done       : One-clock pulse when ciphertext is valid.
 *
 * Operation:
 *   1. The external system provides plaintext and key.
 *   2. The external system pulses start high for one clock cycle.
 *   3. aes_core_baseline performs the full AES-128 encryption.
 *   4. busy stays high while the core is processing.
 *   5. done pulses high when ciphertext is ready.
 *
 * Notes:
 *   - This wrapper is intentionally simple to reduce interface
 *     overhead and make simulation/debugging easier.
 *   - The same interface should be reused for the optimized design
 *     so that both implementations can be tested with the same
 *     testbench style.
 *   - For Quartus compilation, this module can be selected as the
 *     top-level entity for the baseline project.
 * ============================================================
 */

module aes128_baseline
(
    // System clock.
    input  logic         clk,

    // Active-low reset, clears the AES core.
    input  logic         reset_n,

    // Pulse high for one clock to start encryption.
    input  logic         start,

    // 128-bit plaintext input block.
    input  logic [127:0] plaintext,

    // 128-bit AES secret key.
    input  logic [127:0] key,

    // 128-bit ciphertext output block.
    output logic [127:0] ciphertext,

    // High while encryption is in progress.
    output logic         busy,

    // One-clock pulse when ciphertext is valid.
    output logic         done
);

    /*
     * AES core instance.
     *
     * The core contains the actual AES-128 encryption logic:
     *   - state register
     *   - round key register
     *   - key expansion
     *   - round counter
     *   - AES round datapath
     *   - busy/done control logic
     *
     * This top-level wrapper only passes external signals into
     * the core and exposes the core outputs.
     */
    aes_core u_aes_core
    (
        .clk        (clk),
        .reset_n    (reset_n),
        .start      (start),
        .plaintext  (plaintext),
        .key        (key),
        .ciphertext (ciphertext),
        .busy       (busy),
        .done       (done)
    );

endmodule