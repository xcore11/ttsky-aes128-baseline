`default_nettype none
`timescale 1ns/1ps

/*
 * Tiny Tapeout wrapper for the uploaded AES-128 baseline files.
 *
 * Tiny Tapeout has only 8 dedicated input pins and 8 dedicated output pins,
 * so the 128-bit key, plaintext, and ciphertext are transferred byte-by-byte.
 *
 * Byte order:
 *   - Key is loaded most-significant byte first.
 *   - Plaintext is loaded most-significant byte first.
 *   - Ciphertext is read most-significant byte first.
 *
 * Pin usage:
 *   ui_in[7:0]  = input data byte
 *   uo_out[7:0] = current ciphertext output byte
 *
 *   uio_in[0] = pulse high for one clock to load one key byte
 *   uio_in[1] = pulse high for one clock to load one plaintext byte
 *   uio_in[2] = pulse high for one clock to start AES encryption
 *   uio_in[3] = pulse high for one clock to advance ciphertext output byte
 *   uio_in[4] = pulse high for one clock to clear wrapper state
 *
 *   uio_out[5] = busy
 *   uio_out[6] = done_latched / ciphertext valid
 *   uio_out[7] = ready after 16 key bytes and 16 plaintext bytes are loaded
 */

module tt_um_aes128_baseline (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // Command bits from the bidirectional input pins.
    wire load_key_cmd        = uio_in[0];
    wire load_plaintext_cmd  = uio_in[1];
    wire start_cmd           = uio_in[2];
    wire read_next_cmd       = uio_in[3];
    wire clear_cmd           = uio_in[4];

    // Stored 128-bit key and plaintext.
    reg [127:0] key_reg;
    reg [127:0] plaintext_reg;

    // Latched ciphertext after AES completes.
    reg [127:0] ciphertext_reg;

    // Byte counters. They saturate at 16 after the full block is loaded.
    reg [4:0] key_count;
    reg [4:0] plaintext_count;

    // Selected ciphertext byte index for output.
    reg [3:0] read_index;

    // One-clock start pulse into the AES baseline top.
    reg start_reg;

    // Latched done flag so the user can read the ciphertext slowly.
    reg done_latched;

    // AES outputs.
    wire [127:0] ciphertext_wire;
    wire         busy_wire;
    wire         done_wire;

    // The design is ready when both 128-bit input blocks have been loaded.
    wire input_loaded = (key_count == 5'd16) && (plaintext_count == 5'd16);
    wire ready_wire   = input_loaded && !busy_wire;

    // Use ena as part of the internal reset so the design is inactive when disabled.
    wire core_reset_n = rst_n && ena;

    aes128_baseline u_aes128_baseline (
        .clk        (clk),
        .reset_n    (core_reset_n),
        .start      (start_reg),
        .plaintext  (plaintext_reg),
        .key        (key_reg),
        .ciphertext (ciphertext_wire),
        .busy       (busy_wire),
        .done       (done_wire)
    );

    // Drive only uio[7:5] as outputs. uio[4:0] are used as inputs.
    assign uio_oe = 8'b1110_0000;

    assign uio_out[4:0] = 5'b00000;
    assign uio_out[5]   = busy_wire;
    assign uio_out[6]   = done_latched;
    assign uio_out[7]   = ready_wire;

    // Current ciphertext byte output.
    reg [7:0] ciphertext_byte;

    always @* begin
        case (read_index)
            4'd0:    ciphertext_byte = ciphertext_reg[127:120];
            4'd1:    ciphertext_byte = ciphertext_reg[119:112];
            4'd2:    ciphertext_byte = ciphertext_reg[111:104];
            4'd3:    ciphertext_byte = ciphertext_reg[103:96];
            4'd4:    ciphertext_byte = ciphertext_reg[95:88];
            4'd5:    ciphertext_byte = ciphertext_reg[87:80];
            4'd6:    ciphertext_byte = ciphertext_reg[79:72];
            4'd7:    ciphertext_byte = ciphertext_reg[71:64];
            4'd8:    ciphertext_byte = ciphertext_reg[63:56];
            4'd9:    ciphertext_byte = ciphertext_reg[55:48];
            4'd10:   ciphertext_byte = ciphertext_reg[47:40];
            4'd11:   ciphertext_byte = ciphertext_reg[39:32];
            4'd12:   ciphertext_byte = ciphertext_reg[31:24];
            4'd13:   ciphertext_byte = ciphertext_reg[23:16];
            4'd14:   ciphertext_byte = ciphertext_reg[15:8];
            4'd15:   ciphertext_byte = ciphertext_reg[7:0];
            default: ciphertext_byte = 8'h00;
        endcase
    end

    assign uo_out = ciphertext_byte;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            key_reg         <= 128'h0;
            plaintext_reg   <= 128'h0;
            ciphertext_reg  <= 128'h0;
            key_count       <= 5'd0;
            plaintext_count <= 5'd0;
            read_index      <= 4'd0;
            start_reg       <= 1'b0;
            done_latched    <= 1'b0;
        end
        else begin
            // Default: start is a one-clock pulse only.
            start_reg <= 1'b0;

            if (!ena || clear_cmd) begin
                key_reg         <= 128'h0;
                plaintext_reg   <= 128'h0;
                ciphertext_reg  <= 128'h0;
                key_count       <= 5'd0;
                plaintext_count <= 5'd0;
                read_index      <= 4'd0;
                done_latched    <= 1'b0;
            end
            else begin
                // Load key bytes MSB first.
                if (load_key_cmd && !busy_wire && (key_count < 5'd16)) begin
                    key_reg   <= {key_reg[119:0], ui_in};
                    key_count <= key_count + 5'd1;

                    // New input loading invalidates the previous ciphertext.
                    done_latched <= 1'b0;
                    read_index   <= 4'd0;
                end

                // Load plaintext bytes MSB first.
                if (load_plaintext_cmd && !busy_wire && (plaintext_count < 5'd16)) begin
                    plaintext_reg   <= {plaintext_reg[119:0], ui_in};
                    plaintext_count <= plaintext_count + 5'd1;

                    // New input loading invalidates the previous ciphertext.
                    done_latched <= 1'b0;
                    read_index   <= 4'd0;
                end

                // Start encryption after both inputs are fully loaded.
                if (start_cmd && ready_wire && !busy_wire) begin
                    start_reg    <= 1'b1;
                    done_latched <= 1'b0;
                    read_index   <= 4'd0;
                end

                // Latch ciphertext on the AES done pulse.
                if (done_wire) begin
                    ciphertext_reg <= ciphertext_wire;
                    done_latched   <= 1'b1;
                    read_index     <= 4'd0;
                end

                // Advance ciphertext byte output after completion.
                if (read_next_cmd && done_latched && (read_index < 4'd15)) begin
                    read_index <= read_index + 4'd1;
                end
            end
        end
    end

endmodule

`default_nettype wire
