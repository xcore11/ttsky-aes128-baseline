## How it works

This project implements an AES-128 encryption accelerator using the uploaded baseline AES RTL files. The Tiny Tapeout top module is `tt_um_aes128_baseline`, which wraps the internal `aes128_baseline` module and adapts its 128-bit key/plaintext/ciphertext interface to the limited Tiny Tapeout IO pins.

The internal AES block accepts a 128-bit plaintext and a 128-bit key, then produces a 128-bit ciphertext after the encryption operation completes. The AES design exposes a simple `start`, `busy`, and `done` interface.

Because Tiny Tapeout has limited external IO pins, the top-level wrapper uses an 8-bit byte-loading interface:

- `ui_in[7:0]` carries one input byte.
- `uio_in[0]` loads one key byte.
- `uio_in[1]` loads one plaintext byte.
- `uio_in[2]` starts encryption.
- `uio_in[3]` advances the ciphertext output byte.
- `uio_in[4]` clears the wrapper state.
- `uo_out[7:0]` outputs one ciphertext byte.
- `uio_out[5]`, `uio_out[6]`, and `uio_out[7]` report `busy`, `done`, and `ready`.

Bytes are loaded and read most-significant byte first.

## Pin interface

| Pin | Direction | Function |
|---|---:|---|
| `ui_in[7:0]` | Input | Data byte used when loading key or plaintext |
| `uo_out[7:0]` | Output | Current ciphertext output byte |
| `uio_in[0]` | Input | Pulse high for one clock to load one key byte |
| `uio_in[1]` | Input | Pulse high for one clock to load one plaintext byte |
| `uio_in[2]` | Input | Pulse high for one clock to start encryption |
| `uio_in[3]` | Input | Pulse high for one clock to advance to the next ciphertext byte |
| `uio_in[4]` | Input | Pulse high for one clock to clear wrapper counters/status |
| `uio_out[5]` | Output | AES busy status |
| `uio_out[6]` | Output | Done latched / ciphertext valid |
| `uio_out[7]` | Output | Ready for start after key and plaintext are loaded |

## How to test

The cocotb testbench loads a known AES-128 test vector through the Tiny Tapeout byte interface. It loads the 128-bit key and 128-bit plaintext byte-by-byte, pulses the start signal, waits for the `done` status, and reads the 128-bit ciphertext byte-by-byte.

The test checks the following AES-128 vector:

- Key: `000102030405060708090a0b0c0d0e0f`
- Plaintext: `00112233445566778899aabbccddeeff`
- Expected ciphertext: `69c4e0d86a7b0430d8cdb78070b4c55a`

To run the local cocotb test in an environment with Icarus Verilog installed:

```bash
cd test
make clean
make
```

For submission evidence, the Tiny Tapeout GitHub Actions workflows can run the RTL test, GDS hardening, documentation generation, precheck, gate-level simulation, and layout render automatically after pushing the repository.

## External hardware

No external hardware is required for the Tiny Tapeout wrapper test. The design only uses the standard Tiny Tapeout digital IO pins.
