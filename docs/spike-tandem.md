# Spike Tandem Verification for the CV32E20 Core Testbench

The "core" testbench (`tb/core`) can run the Spike instruction-set simulator
in lock-step ("tandem") with the CV32E20 RTL.  Every instruction retired by
the core (as reported on its RISC-V Formal Interface, RVFI) causes Spike to
step by exactly one instruction, and the architectural state changes reported
by the two models are compared.  Any divergence stops the simulation with a
mismatch report.

## Architecture

```
              +---------------------- tb_top -----------------------+
              |  +----------- cv32e20_tb_wrapper ----------------+  |
   test.hex --+--+--> mm_ram <--OBI--> cve2_top (CV32E20)        |  |
              |  |                        |                      |  |
              |  |                        | RVFI (retirements)   |  |
              |  |                        v                      |  |
              |  |                  spike_tandem  <--------------+--+-- +elf_file=test.elf
              |  |                        |                      |  |
              |  +------------------------+----------------------+  |
              +---------------------------+-------------------------+
                                          | DPI-C (spike_create/spike_step)
                                          v
                            libriscv.so (tandem-patched Spike)
```

Components:

- **`tb/core/spike_tandem_pkg.sv`** - DPI-C imports and the `st_rvfi`
  exchange type.  The struct layout must match `riscv/Types.h` of the
  tandem-patched Spike word-for-word (34 scalar 64-bit fields followed by six
  4096-entry CSR arrays).
- **`tb/core/spike_tandem.sv`** - the checker.  Configures Spike at time 0
  (ISA, privilege modes, memory map, CV32E20-specific CSR reset values /
  ID registers), then on every RVFI retirement calls `spike_step_svLogic()`
  and compares PC, instruction word, trap flag, privilege mode, and rd
  writeback (address and data).
- **`vendor_lib/openhwgroup_core-v-verif/vendor/riscv/riscv-isa-sim`** - the
  tandem-patched Spike (`openhw::Simulation`/`openhw::Processor`,
  `riscv_dpi.cc`), vendored inside the core-v-verif clone.  Built into
  `tools/spike/lib/libriscv.so` (and sister libraries) by the `spike_lib`
  target in `mk/Common.mk`.

The same test-program image is given to both models: the testbench loads the
Verilog-hex file into `mm_ram` (`+test_program=`), and Spike loads the ELF the
hex was generated from (`+elf_file=`, added automatically by the Makefile).

## Usage

```bash
cd sim/core
make test TEST=hello-world SPIKE_TANDEM=1
```

`SPIKE_TANDEM=1`:

- builds the Spike libraries first if they are missing (`spike_lib` target;
  requires the core-v-verif clone in `vendor_lib`, see the `core-v-verif`
  target),
- compiles the RTL with `+define+RVFI` so `cve2_top` exposes its RVFI ports,
- compiles `spike_tandem_pkg.sv`/`spike_tandem.sv` into the testbench and
  links the Spike libraries,
- passes `+elf_file=<test>.elf` to the simulation.

On success the simulation ends with the usual test status plus:

```
[spike_tandem] <N> instructions verified in tandem with Spike
```

On divergence the simulation stops immediately:

```
[spike_tandem] MISMATCH rd_wdata: rtl=0x12345678 spike=0x9abcdef0 (rd=x10)
[spike_tandem] @ t=...: TANDEM MISMATCH at retirement <N> (1 field(s) differ)
[spike_tandem]   rtl:   pc=... insn=... rd=... rd_wdata=... trap=... mode=...
[spike_tandem]   spike: pc=... insn=... rd=... rd_wdata=... trap=... mode=...
```

### Plusargs

| Plusarg                   | Purpose                                              |
| ------------------------- | ---------------------------------------------------- |
| `+elf_file=<path>`        | ELF for Spike (set automatically by the Makefile)    |
| `+tandem_trace`           | Print every retirement as it is verified             |
| `+tandem_inject_error=<n>`| Self-test: corrupt the RTL rd value at retirement n  |

The error-injection plusarg deliberately falsifies the RTL-side rd write
value presented to the comparator and must always produce a TANDEM MISMATCH
(provided retirement *n* writes a register other than x0).  Use it to verify
that the checker is armed.

## Spike configuration details

The checker mirrors the RTL configuration in `spike_tandem_init()`:

- **ISA / priv**: `rv32imc_zicsr_zifencei`, privilege modes M+U.  This
  reproduces the RTL `misa` value 0x40101104 (cve2_cs_registers.sv).
- **Boot address**: Spike's PC after reset is set to `{BOOT_ADDR[31:2],2'b00}`
  (the CVE2 fetches its first instruction at the boot address directly; there
  is no Spike boot ROM in this configuration).
- **Memory map**: a single sparse memory region `[0x0, 0x2100_0000)` covering
  the 4 MiB testbench RAM and all mm_ram virtual peripheral addresses
  (print @0x1000_0000, test status @0x2000_00xx, timers, debugger sections),
  so that stores to peripherals do not fault in Spike.
- **ID CSRs**: `mvendorid=0x602`, `marchid=35`, `mimpid=0`, `mhartid=HART_ID`
  via Spike CSR override parameters (values from `cve2_pkg.sv`).
- **mtvec**: reset value `{BOOT_ADDR[31:8], 8'h01}` (vectored mode), write
  mask `0xFFFFFF00` - matching the CVE2, where mtvec writes update only
  [31:8] and the low byte always reads 0x01.
- **mstatus**: reset value 0x1800 (MPP=M).
- **Trigger module**: one trigger, `tdata1` reset value 0x28001048, tdata1
  writes suppressed, `tinfo` not present (values from the proven `cve2`
  profile in core-v-verif's `rvfi_spike.sv`).
- **Counter CSR reads**: `csr_counters_injection` makes Spike adopt the RTL
  value when the program reads free-running counters (cycle/mcycle/mip), so
  these do not cause false mismatches.

## Interrupt injection

Asynchronous interrupts are injected into Spike (`interrupts_injection=1`) so
that tests using the mm_ram interrupt peripherals no longer mismatch at the
first taken interrupt.

CVE2's RVFI interface truncates away the info Spike needs for this: its
top-level 1-bit `rvfi_intr` port is assigned from an internal 9-bit
`rvfi_stage_intr[RVFI_STAGES-1]` value (`cve2_core.sv`) encoding
`{mcause[5:0], 3'b101}` for an asynchronous-interrupt-entry retirement (or
`3'b011` for a synchronous exception entry), but only its LSB reaches the
module boundary. `cv32e20_tb_wrapper.sv` recovers the full value with a
whitebox hierarchical probe (`cv32e20_top_inst.u_cve2_core.rvfi_stage_intr[0]`
- valid since `RVFI_STAGES=1` for this core, so the signal is exactly
time-aligned with `rvfi_valid`) and passes it into `spike_tandem` as
`rvfi_intr_cause[8:0]`. On an interrupt-entry retirement, `spike_tandem.sv`
sets the RTL-side `st_rvfi.intr` field to `0b101` and populates
`csr_rdata[CSR_MCAUSE]`; `openhw::Processor::step()` (`Proc.cc`) checks for
that pattern, reads the injected mcause, converts it to a `mip` bit via
`mcause_to_mip()`, and backdoor-writes Spike's `mip` so it takes the same
interrupt the RTL just did.

This also requires `unified_traps=1`. Without it, the DPI call that injects
the interrupt only takes the trap (redirecting Spike's PC to the handler) and
returns immediately, without fetching the handler's first instruction -
leaving that instruction's RVFI info misaligned by one DPI call relative to
the RTL's single retirement. `unified_traps=1` makes Spike's step loop
continue past the trap-taking to actually retire the handler's first
instruction in the same call.

## Current limitations (phase 1)

- **Debug mode is not modeled** (`debug_injection=0`): debug-request tests
  will mismatch on entry to the debug ROM.
- **Loads from testbench virtual peripherals** (e.g. the mm_ram timer
  registers or random-number register) return values Spike cannot predict and
  will mismatch.  Stores are harmless.
- **CSR write-back values are not compared** - only the GPR effects of CSR
  instructions are checked.  Full CSR comparison is planned with the RVVI
  wrapper (see below).
- The comparison covers PC, instruction word, trap flag, privilege mode and
  rd write-back.  Memory access address/data comparison is not yet enabled.

## Bring-up results (2026-06-11, interrupt injection added 2026-09-02)

| Test                          | Result | Retirements verified | Notes                                   |
| ----------------------------- | ------ | -------------------- | --------------------------------------- |
| hello-world                   | PASS   | 10,837               | includes ID-CSR reads                    |
| fibonacci                     | PASS   | 69,443               |                                          |
| misalign                      | PASS   | 208,231              | hardware-handled misaligned accesses     |
| illegal                       | PASS   | 5,865                | illegal-instruction exception + handler  |
| riscv_arithmetic_basic_test_0 | PASS   | 11,422               |                                          |
| dhrystone                     | PASS   | 118,860              |                                          |
| branch_zero                   | PASS   | 3,750,790            | mm_ram fast interrupts; see Interrupt injection above |

The `+tandem_inject_error` self-test was verified to abort the simulation
with a `TANDEM MISMATCH` report when the RTL-side rd value is corrupted.

## Relationship to the RVVI-API

This phase-1 integration uses the CVA6-style `spike_create()`/`spike_step()`
DPI interface that ships with the tandem-patched Spike.  The longer-term goal
of the SPIKE_TANDEM project is to wrap the Spike reference model behind the
standard [RVVI-API](https://github.com/riscv-verification/RVVI) so that the
testbench-side protocol is reference-model agnostic.  The checker module was
written so that only `spike_tandem_init()` and `tandem_step()` need to change
when that wrapper exists.

## Rebuilding Spike

```bash
cd sim/core
make spike_lib            # builds into <repo>/tools/spike/{lib,include}
```

The Spike build needs `svdpi.h`; the Makefile locates it from the Verilator
in `$PATH` (`verilator --getenv VERILATOR_ROOT`).
