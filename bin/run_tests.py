#!/usr/bin/env python3
# Copyright (c) 2026 Eclipse Foundation
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
"""
Run the cleaned-up directed test-programs (C and assembly) on a CV32E20
testbench and print a pass/fail summary.  Either testbench can be selected
with --tb:

    core   the Verilator core testbench in sim/core            (default)
    uvmt   the UVM testbench in sim/uvmt, run with SIMULATOR=vsim

For each selected test the script invokes `make test TEST=<name> ...` in the
chosen testbench's sim directory, then parses the per-test log it leaves behind
for the verdict banner:

    core : sim/core/simulation_results/<name>/<run>/test_program/<name>.log
           "ALL TESTS PASSED"   -> PASS   (tb/core/tb_top.sv)
           "TEST(S) FAILED!"    -> FAIL

    uvmt : sim/uvmt/vsim_results/<cfg>/<name>/<run>/vsim-<name>.log
           "SIMULATION PASSED"  -> PASS   (tb/uvmt/uvmt_cv32e20_tb.sv;
                                           includes "PASSED with WARNINGS")
           "SIMULATION FAILED"  -> FAIL

Anything else (no banner, build error, timeout) is reported as ERROR.
The process exit code is 0 only if every test that was run reported PASS.

corev-dv tests (see COREV_DV_TESTS below) additionally need `make corev-dv`
run once beforehand to clone and compile the corev-dv/riscv-dv packages
(uvmt only). Whenever the selected set includes any corev-dv test, this
script runs `make corev-dv` itself before running any tests, and aborts if
that setup step fails.

For corev-dv tests, --run-index also selects which generated program directory
is used: run_test() passes it through as both RUN_INDEX (where the build/run
step looks for the program) and GEN_START_INDEX (where gen_corev-dv writes it).
run_test() also passes SEED=random for every corev-dv test, so each invocation
uses a fresh RNDSEED (mk/uvmt/uvmt.mk derives it from `date +%N`) for both the
corev-dv generator and the env-level randomization -- re-running the same
--run-index does NOT reproduce the same generated program/stimulus anymore.
The actual seed used is recorded in that run's vsim-<name>.log header
(`-sv_seed <value>`) for later replay via SEED=<value>.

Usage
-----
The script needs no arguments and can be run from anywhere (paths are resolved
relative to its own location in <repo>/bin).  A working RISC-V toolchain plus
the relevant simulator (Verilator for core, Questa vsim for uvmt) must be on
PATH, as for a normal `make test`.

    # Run the full self-checking set (C + assembly) on the core TB:
    bin/run_tests.py
    python3 bin/run_tests.py                    # equivalent

    # Run the same set on the UVM testbench (vsim), plus UVMT_TESTS (directed
    # tests that only make sense under uvmt, e.g. nmi_test):
    bin/run_tests.py --tb uvmt
    # (equivalent to `make test TEST=<name> SIMULATOR=vsim` per test; the
    #  script sets SIMULATOR=vsim for you, so no need to export it yourself.)

    # Run only specific tests (by directory name under tests/programs/custom):
    bin/run_tests.py fibonacci misalign
    bin/run_tests.py --tb uvmt hello-world

    # Also run the parked tests (step-compare / debug; meaningful under --tb uvmt):
    bin/run_tests.py --include-parked
    bin/run_tests.py --tb uvmt --include-parked

    # Also run the passing corev-dv generated regression tests (uvmt only):
    bin/run_tests.py --tb uvmt --include-corev-dv

    # Run ONLY the corev-dv generated regression tests (uvmt only):
    bin/run_tests.py --tb uvmt --corev-dv-only

    # Skip simulation; just re-summarize logs from a previous run:
    bin/run_tests.py --parse-only
    bin/run_tests.py --tb uvmt --parse-only

    # Run up to 4 tests concurrently (uvmt only is verified safe -- see below):
    bin/run_tests.py --tb uvmt --corev-dv-only --jobs 4

    # Replay a specific prior corev-dv run from its logged seeds (gen_corev-dv
    # and test are independent UVM environments/vsim invocations, each with
    # their own seed -- see the summary table's GEN_SEED/RUN_SEED columns):
    bin/run_tests.py --tb uvmt --gen-seed 363891135 --run-seed 354410829 \
        corev_rand_instr_and_data_stalls

    # Collect code coverage (uvmt only; equivalent to `make test ... COV=1` per test):
    bin/run_tests.py --tb uvmt --cov hello-world

    # Other options:
    #   --cfg NAME      uvmt config subdirectory                (default: default)
    #   --run-index N   RUN_INDEX subdirectory                  (default: 0)
    #   --gen-seed SEED corev-dv generator SEED ('random' or a literal value)
    #   --run-seed SEED test-step SEED ('random' or a literal value)
    #   --timeout SECS  per-test timeout                        (default: 1800)
    #   --jobs N, -j N  run up to N tests concurrently           (default: 1)
    #   --cov           collect code coverage (uvmt only)
    #   --quiet         suppress per-test simulation banners
    #   -h / --help     full option help

Exit status is 0 only when every selected test PASSED, so the script is
suitable for use as a CI gate.

Concurrency (--jobs)
--------------------
By default (--jobs 1) each test runs its own `make test`/`make gen_corev-dv
test`, which recompiles the design every time (VSIM_RUN_PREREQ=opt unless
COMP=NO is passed). Running that concurrently would race multiple vlog/vopt
invocations against the same shared vsim work library
(sim/uvmt/vsim_results/<cfg>/work) -- a previously-confirmed hazard (lock
contention or "already an optimized design" errors).

With --jobs > 1 and --tb uvmt, this script instead compiles the design ONCE
up front (`make comp`, serialized, in addition to the existing one-time `make
corev-dv` setup for corev-dv tests) and then passes COMP=NO to every test in
the parallel batch, so workers only run `vsim` against the already-compiled
design. If --cov is also given, that one-time compile is done with COV=1 too
(otherwise the shared design has no +cover instrumentation and every
worker's .ucdb ends up with assertions/covergroups but zero statement/
branch/condition coverage, since COMP=NO skips each worker's own vopt) --
each worker runs in its own per-test/run-index run directory
(sim/uvmt/vsim_results/<cfg>/<test>/<run_index>/), which `make`'s `run`
target `vmap`s back to the shared read-only compiled library. Many `vsim`
processes reading one compiled snapshot concurrently is a standard, safe
regression-farm pattern; it's concurrent *compilation* that isn't safe.

Caveat: the corev-dv random-program *generation* step (gen_corev-dv) itself
runs vsim from within a directory shared by all corev-dv tests
(vsim_results/<cfg>/corev-dv/), unlike the isolated per-test run directories
above. This looks benign under concurrency (per-test/idx log files don't
collide, and the shared `vmap` writes identical content regardless of which
process wins the race) but has not been independently stress-tested at high
--jobs counts. Keep an eye on it if you push --jobs high for corev-dv-heavy
batches.

--tb core (Verilator) has NOT been verified race-free under --jobs > 1: `make
test` for the core TB also recompiles into a shared directory
(sim/core/cobj_dir) on every invocation, and no COMP=NO-equivalent skip-flag
was found for it. Prefer --jobs 1 there unless you've confirmed otherwise.

Also keep the vsim license pool in mind (`lmutil lmstat`) -- each concurrent
uvmt worker holds its own set of Questa feature licenses (msimhdlsim,
svverification, mtiverification, ...) for the duration of its run.
"""

import argparse
import concurrent.futures
import os
import re
import signal
import subprocess
import sys
import threading
from pathlib import Path

# Repository layout: this script lives in <repo>/bin.
SCRIPT_DIR = Path(__file__).resolve().parent
REPO = SCRIPT_DIR.parent

# Guards stdout so concurrent workers (--jobs > 1) don't interleave lines from
# different tests mid-block; each worker holds it only long enough to print
# its own (possibly multi-line) announcement or banner block.
_print_lock = threading.Lock()

# Per-testbench configuration.  Each entry knows where to run make, which extra
# make arguments to pass, the verdict banners its testbench prints, and how to
# locate a test's log file.
TESTBENCHES = {
    "core": {
        "sim_dir": REPO / "sim" / "core",
        "make_args": [],
        "pass_banner": "ALL TESTS PASSED",
        "fail_banner": "TEST(S) FAILED!",
        # Progress lines worth echoing while a test runs.
        "markers": ("tb_top]", "SUCCESS", "FAIL"),
    },
    "uvmt": {
        "sim_dir": REPO / "sim" / "uvmt",
        "make_args": ["SIMULATOR=vsim", "USE_ISS=NO"],
        "pass_banner": "SIMULATION PASSED",
        "fail_banner": "SIMULATION FAILED",
        "markers": ("SIMULATION PASSED", "SIMULATION FAILED",
                    "UVM_ERROR :", "UVM_FATAL :", "TEST PASSED", "TEST FAILED"),
    },
}

# Self-checking C test-programs cleaned up on this branch.  These verify their
# own results and signal the canonical pass/fail, so they pass on the core TB.
C_TESTS = [
    "hello-world",
    "fibonacci",
    "branch_zero",
    "coremark",
    "dhrystone",
#    "all_csr_por",
    "csr_instructions",
    "hpmcounter_basic_test",
    "illegal",
    "misalign",
    "interrupt_test",
    "interrupt_bootstrap",
    "debug_test",
]

# Self-checking assembly test-programs cleaned up on this branch.  Each was
# fixed to build and to signal end-of-test through the canonical protocol
# (TEST_PASS/TEST_FAIL in bsp/cv32e20_dv.h, writing 123456789 / 1); each passes
# on the core TB.
ASM_TESTS = [
    "load_store_rs1_zero",
    "illegal_instr_test",
    "generic_exception_test",
    "csr_instr_asm",
]

# Default (core TB) selection: every self-checking test, C and assembly.
TESTS = C_TESTS + ASM_TESTS

# Parked tests: these build and signal correctly, but their *meaningful*
# verification is not a self-check on the core TB.  Included only with
# --include-parked, and intended to be run with --tb uvmt:
#   * riscv_arithmetic_basic_test_0/1 and csr_instr_asm exercise long fixed
#     instruction streams whose correctness is checked by the RVFI step-compare
#     against the Spike ISS (sim/uvmt); on the core TB they pass *vacuously*.
#   * riscv_csr additionally needs the M-only counter-CSR reconciliation (see
#     README parked-work notes).
#   * the debug_test variants need the uvmt debug-request stimulus; on the core
#     TB they report FAIL because debug mode is never entered.
PARKED = [
    "riscv_arithmetic_basic_test_0",
    "riscv_arithmetic_basic_test_1",
    "csr_instr_asm",
    "riscv_csr",
    "perf_counters_instructions",
    "debug_test_boot_set",
    "debug_test_reset",
    "debug_test_known_miscompares",
    "debug_test_trigger",
]

# Directed tests that are part of the standard regression (unlike PARKED,
# not opt-in) but only make sense on the uvmt TB, since they need uvmt-only
# stimulus with no core-TB equivalent. Automatically added to the default
# selection whenever --tb uvmt is chosen (see main()); ignored for --tb core.
#   * nmi_test needs the uvmt interrupt-agent's +nmi_assert stimulus (see
#     uvme_cv32e20_nmi_assert_vseq.sv); on the core TB the NMI line is never
#     asserted.
UVMT_TESTS = [
    "nmi_test",
]

# corev-dv (OpenHW's class extensions of Google's riscv-dv) generated regression
# templates under tests/programs/corev-dv/.  Unlike C_TESTS/ASM_TESTS/PARKED,
# each of these needs its randomized test program generated before it can be
# built and run, i.e. `make gen_corev-dv test TEST=<name>` rather than plain
# `make test TEST=<name>`, where run_test() adds the extra target automatically for
# names in this list. Meaningful only under --tb uvmt (corev-dv generation is
# wired up for the uvmt testbench only); included only with --include-corev-dv
# or --corev-dv-only.
#
# Before any test in this list can build, `make corev-dv` (clone + compile the
# corev-dv/riscv-dv packages) must have been run once in sim/uvmt; main() does
# this automatically whenever the selected set includes a corev-dv test.
#
COREV_DV_TESTS = [
    "corev_rand_arithmetic_base_test",
    "corev_rand_instr_test",
    "corev_rand_interrupt",
    "corev_rand_interrupt_debug",
    "corev_rand_interrupt_exception",
    "corev_rand_interrupt_nested",
    "corev_rand_interrupt_wfi",
    "corev_rand_interrupt_wfi_mem_stress",
    "corev_rand_jump_stress_test",
    "corev_rand_debug",
    "corev_rand_debug_ebreak",
    "corev_rand_debug_single_step",
    "corev_rand_illegal_instr_test",
    "corev_rand_instr_long_stall",
    "corev_rand_instr_and_data_stalls",
]


def log_path(tb, test, run_index, cfg):
    """Location of the per-test simulation log for the given testbench."""
    sim_dir = TESTBENCHES[tb]["sim_dir"]
    if tb == "core":
        return (sim_dir / "simulation_results" / test / str(run_index)
                / "test_program" / f"{test}.log")
    # uvmt / vsim
    return (sim_dir / "vsim_results" / cfg / test / str(run_index)
            / f"vsim-{test}.log")


def gen_log_path(tb, test, run_index, cfg):
    """Location of the corev-dv generation step's own log file. This is a
    fully separate vsim invocation/UVM environment from the test's own
    vsim-<test>.log (log_path() above) -- gen_corev-dv builds the randomized
    instruction stream, test builds+runs the firmware -- so it gets its own
    independent -sv_seed. GEN_NUM_TESTS is never overridden by this script
    (Makefile default 1), hence the fixed "_1" in the filename."""
    sim_dir = TESTBENCHES[tb]["sim_dir"]
    return (sim_dir / "vsim_results" / cfg / "corev-dv" / test
            / f"{test}_{run_index}_1.log")


_SEED_RE = re.compile(r"-sv_seed\s+(\S+)")


def extract_seed(text):
    """Pull the actual -sv_seed value a vsim invocation was run with out of
    its console output or log file. Needed whenever SEED=random is used --
    the Makefile picks the real value internally (`date +%N`), so the caller
    never sees it on the command line it constructed."""
    m = _SEED_RE.search(text)
    return m.group(1) if m else None


def classify(text, tbcfg):
    """Return 'PASS', 'FAIL', or 'ERROR' for a chunk of log/console text."""
    if tbcfg["pass_banner"] in text:
        return "PASS"
    if tbcfg["fail_banner"] in text:
        return "FAIL"
    return "ERROR"


def make_env(tbcfg):
    """Environment for a make invocation: os.environ plus tbcfg's make_args
    (e.g. SIMULATOR=vsim) mirrored in, so any sub-make/shell that reads the
    variable directly behaves consistently with what's on the command line."""
    env = os.environ.copy()
    for arg in tbcfg["make_args"]:
        key, _, val = arg.partition("=")
        if val:
            env[key] = val
    return env


def _run(cmd, cwd, env, timeout, capture):
    """Run cmd in its own process group (session) so a timeout can kill the
    whole tree, not just the immediate child. Without this, a `make` that
    times out leaves its own child (e.g. vsim) running as an orphan: the
    simulation keeps going for real in the background while the script
    reports a false timeout and moves on to the next test."""
    proc = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=env,
        start_new_session=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        text=True,
    )
    try:
        stdout, stderr = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        proc.communicate()
        raise
    return proc.returncode, stdout, stderr


def setup_corev_dv(tb, timeout):
    """Run `make corev-dv` once: clones and compiles the corev-dv/riscv-dv
    packages.  Required before any COREV_DV_TESTS entry can build; aborts the
    script on failure since no corev-dv test can proceed without it."""
    tbcfg = TESTBENCHES[tb]
    cmd = ["make", "corev-dv"] + tbcfg["make_args"]
    env = make_env(tbcfg)

    print(f"[Setup/{tb}] make corev-dv ...")
    try:
        returncode, _, _ = _run(cmd, tbcfg["sim_dir"], env, timeout, capture=False)
    except subprocess.TimeoutExpired:
        sys.exit(f"error: 'make corev-dv' timed out after {timeout}s")
    except OSError as exc:
        sys.exit(f"error: could not launch 'make corev-dv': {exc}")

    if returncode != 0:
        sys.exit(f"error: 'make corev-dv' failed (exit {returncode}); "
                  "no corev-dv test can build without it")


def setup_comp(tb, timeout, cov=False):
    """Run `make comp` once: compiles the main testbench (uvmt_*_tb_vopt) into
    the shared work library. Required before a --jobs > 1 batch can safely
    pass COMP=NO to its workers -- without a compiled design already sitting
    in the shared library, every worker would either fail (nothing to run
    against) or race to compile it themselves. Aborts the script on failure.

    cov: pass COV=1 to this compile so vopt instruments the design with
    +cover -- required when the --jobs > 1 batch will also run with --cov,
    since workers pass COMP=NO and reuse this shared compile as-is (without
    this, every worker's .ucdb ends up with no statement/branch/condition
    coverage at all, only assertions/covergroups)."""
    tbcfg = TESTBENCHES[tb]
    cmd = ["make", "comp"] + tbcfg["make_args"]
    if cov:
        cmd.append("COV=1")
    env = make_env(tbcfg)

    print(f"[Setup/{tb}] make comp (one-time compile for --jobs > 1) ...")
    try:
        returncode, _, _ = _run(cmd, tbcfg["sim_dir"], env, timeout, capture=False)
    except subprocess.TimeoutExpired:
        sys.exit(f"error: 'make comp' timed out after {timeout}s")
    except OSError as exc:
        sys.exit(f"error: could not launch 'make comp': {exc}")

    if returncode != 0:
        sys.exit(f"error: 'make comp' failed (exit {returncode}); "
                  "no test can build without it")


def run_test(tb, test, run_index, cfg, timeout, quiet, extra_make_args=None,
             label=None, gen_seed="random", run_seed="random", cov=False):
    """Build+run one test on the chosen testbench; return
    (outcome, detail, gen_seed_used, run_seed_used).

    For corev-dv tests, gen_corev-dv (the corev-dv/riscv-dv random program
    generator) and test (the actual firmware run) are two fully independent
    UVM environments/vsim invocations that compile and run separately -- so
    each gets its own `make` invocation and its own independent SEED=
    assignment, rather than one combined `make gen_corev-dv test` call. That
    matters for reproduction: a single SEED=<literal value> on one combined
    invocation would force both steps to the *same* RNDSEED (mk/uvmt/uvmt.mk
    only re-derives a fresh value from `date +%N` when SEED=random; a literal
    value is just reused as-is), which can't reproduce a historical run where
    the two steps happened to draw different random seeds.
    gen_seed_used/run_seed_used are the actual -sv_seed values each step's
    vsim was invoked with (extracted from console/log output -- needed
    whenever SEED=random, since the Makefile picks the real value internally
    and it never appears on the command line this function constructs).
    Both are None for non-corev-dv tests, which have no separate generation
    step and are never given an explicit SEED.

    extra_make_args: additional make variable assignments appended to each
    command line (e.g. ["COMP=NO"] for a --jobs > 1 batch that already had
    setup_comp() run once beforehand).
    cov: pass COV=1 to the actual firmware build+run (equivalent to `make
    test ... COV=1`), so vopt instruments the design and Questa writes a
    .ucdb -- see docs/COVERAGE-MAKE-TARGETS.md for the report targets that
    consume it. Deliberately NOT passed to the gen_corev-dv step above: that's
    a separate UVM environment/vsim invocation (the random-program generator,
    unrelated to the DUT), so instrumenting it would be pointless.
    label: when set (--jobs > 1), prefixes each printed banner line with the
    test name so concurrent workers' output stays distinguishable; printing
    is done as one locked block per test so lines from different tests can't
    interleave mid-line.
    """
    tbcfg = TESTBENCHES[tb]
    env = make_env(tbcfg)
    gen_seed_used = None

    if test in COREV_DV_TESTS:
        # gen_corev-dv generates into <test>/$(GEN_START_INDEX)/test_program/,
        # independently of RUN_INDEX (which only selects where the build/run
        # step looks for that program). Without this, a non-zero --run-index
        # generates into .../0/ but builds/runs out of .../<run_index>/, which
        # is empty except for the BSP.
        gen_cmd = (["make", "gen_corev-dv", f"TEST={test}",
                     f"GEN_START_INDEX={run_index}", f"SEED={gen_seed}"]
                    + tbcfg["make_args"])
        if extra_make_args:
            gen_cmd += extra_make_args

        try:
            returncode, gstdout, gstderr = _run(gen_cmd, tbcfg["sim_dir"], env,
                                                 timeout, capture=True)
        except subprocess.TimeoutExpired:
            return "ERROR", f"gen_corev-dv timed out after {timeout}s", None, None
        except OSError as exc:
            return "ERROR", f"could not launch gen_corev-dv make: {exc}", None, None

        gen_seed_used = extract_seed(gstdout + gstderr)
        if gen_seed_used is None:
            gpath = gen_log_path(tb, test, run_index, cfg)
            if gpath.is_file():
                gen_seed_used = extract_seed(gpath.read_text(errors="replace"))

        if returncode != 0:
            return ("ERROR", f"gen_corev-dv failed (exit {returncode})",
                    gen_seed_used, None)

    cmd = ["make", "test", f"TEST={test}", f"RUN_INDEX={run_index}"]
    if test in COREV_DV_TESTS:
        cmd.append(f"SEED={run_seed}")
    if cov:
        cmd.append("COV=1")
    cmd += tbcfg["make_args"]
    if extra_make_args:
        cmd += extra_make_args

    try:
        returncode, stdout, stderr = _run(cmd, tbcfg["sim_dir"], env, timeout, capture=True)
    except subprocess.TimeoutExpired:
        return "ERROR", f"timed out after {timeout}s", gen_seed_used, None
    except OSError as exc:
        return "ERROR", f"could not launch make: {exc}", gen_seed_used, None

    if not quiet:
        lines = [line for line in stdout.splitlines()
                 if any(m in line for m in tbcfg["markers"])]
        if lines:
            prefix = f"    [{label}] " if label else "    "
            with _print_lock:
                for line in lines:
                    print(prefix + line)

    # The console output is authoritative for the run we just launched; fall
    # back to the on-disk log if the banner did not reach stdout.
    console = stdout + stderr
    run_seed_used = extract_seed(console)
    outcome = classify(console, tbcfg)
    if outcome == "ERROR" or run_seed_used is None:
        path = log_path(tb, test, run_index, cfg)
        if path.is_file():
            log_text = path.read_text(errors="replace")
            if outcome == "ERROR":
                outcome = classify(log_text, tbcfg)
            if run_seed_used is None:
                run_seed_used = extract_seed(log_text)

    if outcome != "ERROR":
        return outcome, "", gen_seed_used, run_seed_used
    if returncode != 0:
        return "ERROR", f"make exited {returncode}", gen_seed_used, run_seed_used
    return "ERROR", "no verdict banner", gen_seed_used, run_seed_used


def parse_only(tb, test, run_index, cfg):
    """Read an existing log file without re-running the simulation; return
    (outcome, detail, gen_seed_used, run_seed_used), same shape as run_test()."""
    path = log_path(tb, test, run_index, cfg)
    if not path.is_file():
        return "ERROR", "no log file", None, None

    text = path.read_text(errors="replace")
    run_seed_used = extract_seed(text)
    gen_seed_used = None
    if test in COREV_DV_TESTS:
        gpath = gen_log_path(tb, test, run_index, cfg)
        if gpath.is_file():
            gen_seed_used = extract_seed(gpath.read_text(errors="replace"))

    return classify(text, TESTBENCHES[tb]), "", gen_seed_used, run_seed_used


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tests", nargs="*",
                    help="specific test names to run (default: the full cleaned-up set)")
    ap.add_argument("--tb", choices=sorted(TESTBENCHES), default="core",
                    help="testbench to run on: 'core' (Verilator) or 'uvmt' (vsim) "
                         "(default: core)")
    ap.add_argument("--include-parked", action="store_true",
                    help="also run the parked tests (step-compare arithmetic/CSR and "
                         "debug variants; meaningful under --tb uvmt)")
    ap.add_argument("--include-corev-dv", action="store_true",
                    help="also run the passing corev-dv generated regression tests "
                         "(uvmt only; each needs an extra gen_corev-dv step)")
    ap.add_argument("--corev-dv-only", action="store_true",
                    help="run ONLY the corev-dv generated regression tests (uvmt "
                         "only); cannot be combined with test names, "
                         "--include-parked, or --include-corev-dv")
    ap.add_argument("--parse-only", action="store_true",
                    help="do not run; just parse existing logs in the results directory")
    ap.add_argument("--cfg", default="default",
                    help="uvmt config subdirectory under vsim_results (default: default)")
    ap.add_argument("--run-index", type=int, default=0,
                    help="RUN_INDEX subdirectory to use (default: 0)")
    ap.add_argument("--timeout", type=int, default=1800,
                    help="per-test timeout in seconds (default: 1800; the "
                         "interrupt-heavy corev-dv templates routinely take "
                         "10-15 minutes including compile)")
    ap.add_argument("--gen-seed", default="random",
                    help="SEED for the corev-dv generation step (gen_corev-dv; "
                         "the random-instruction-stream generator). 'random' "
                         "(default) or a literal value to replay a specific "
                         "prior run -- see --run-seed, a fully independent "
                         "knob (gen_corev-dv and test are separate UVM "
                         "environments/vsim invocations, each seeded "
                         "separately). No effect on non-corev-dv tests.")
    ap.add_argument("--run-seed", default="random",
                    help="SEED for the test step (the actual firmware run's "
                         "env-level randomization, e.g. OBI stall knobs). "
                         "'random' (default) or a literal value to replay a "
                         "specific prior run. No effect on non-corev-dv tests.")
    ap.add_argument("--cov", action="store_true",
                    help="collect code coverage (uvmt only; equivalent to "
                         "`make test ... COV=1` per test). Requires "
                         "sim/tools/vsim/cov.tcl to exist, or Questa silently "
                         "collects nothing -- see docs/COVERAGE-MAKE-TARGETS.md "
                         "for the report targets (cov, cov_txt, cov_holes, "
                         "cov_holes_details) that consume the resulting .ucdb.")
    ap.add_argument("--quiet", action="store_true",
                    help="suppress per-test simulation banner output")
    ap.add_argument("--jobs", "-j", type=int, default=1,
                    help="run up to N tests concurrently (default: 1, sequential). "
                         "See the 'Concurrency' section of --help for the safety "
                         "model (uvmt only is verified race-free; core is not).")
    args = ap.parse_args()

    if args.jobs < 1:
        ap.error("--jobs must be >= 1")

    if args.cov and args.tb != "uvmt":
        ap.error("--cov requires --tb uvmt (Questa coverage; the core "
                  "Verilator testbench has no COV support)")

    if args.corev_dv_only:
        if args.tests or args.include_parked or args.include_corev_dv:
            ap.error("--corev-dv-only cannot be combined with test names, "
                      "--include-parked, or --include-corev-dv")
        selected = list(COREV_DV_TESTS)
    elif args.tests:
        selected = args.tests
    else:
        selected = list(TESTS)
        if args.tb == "uvmt":
            selected += UVMT_TESTS
        if args.include_parked:
            selected += PARKED
        if args.include_corev_dv:
            selected += COREV_DV_TESTS

    sim_dir = TESTBENCHES[args.tb]["sim_dir"]
    if not sim_dir.is_dir():
        sys.exit(f"error: sim directory for --tb {args.tb} not found at {sim_dir}")

    needs_corev_dv = any(test in COREV_DV_TESTS for test in selected)
    if needs_corev_dv and not args.parse_only:
        if args.tb != "uvmt":
            sys.exit("error: corev-dv tests require --tb uvmt")
        setup_corev_dv(args.tb, args.timeout)

    extra_make_args = []
    if args.jobs > 1 and not args.parse_only:
        if args.tb == "uvmt":
            # One-time serialized compile so the parallel batch below can pass
            # COMP=NO and safely skip recompilation instead of racing on the
            # shared vsim work library -- see the "Concurrency" section of
            # --help for the full explanation.
            setup_comp(args.tb, args.timeout, cov=args.cov)
            extra_make_args = ["COMP=NO"]
        else:
            print(f"warning: --jobs {args.jobs} with --tb core has not been "
                  "verified race-free against the shared Verilator build "
                  "directory (sim/core/cobj_dir); proceeding anyway, but "
                  "prefer --jobs 1 unless you've confirmed it's safe.")

    def run_one(test):
        action = "Parsing" if args.parse_only else "Running"
        with _print_lock:
            print(f"[{action}/{args.tb}] {test} ...")
        if args.parse_only:
            outcome, detail, gen_seed, run_seed = parse_only(
                args.tb, test, args.run_index, args.cfg)
        else:
            outcome, detail, gen_seed, run_seed = run_test(
                args.tb, test, args.run_index, args.cfg,
                args.timeout, args.quiet,
                extra_make_args=extra_make_args,
                label=test if args.jobs > 1 else None,
                gen_seed=args.gen_seed, run_seed=args.run_seed,
                cov=args.cov)
        if args.jobs > 1:
            done = "Parsed" if args.parse_only else "Done"
            with _print_lock:
                print(f"[{done}/{args.tb}] {test}: {outcome} {detail}".rstrip())
        return test, outcome, detail, gen_seed, run_seed

    width = max(len(t) for t in selected)
    if args.jobs == 1:
        results = [run_one(test) for test in selected]
    else:
        outcomes = {}
        with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
            futures = [pool.submit(run_one, test) for test in selected]
            for future in concurrent.futures.as_completed(futures):
                test, outcome, detail, gen_seed, run_seed = future.result()
                outcomes[test] = (test, outcome, detail, gen_seed, run_seed)
        # Report in the original --selected order regardless of completion order.
        results = [outcomes[test] for test in selected]

    # Summary. GEN_SEED/RUN_SEED are "-" for non-corev-dv tests (no generation
    # step, no explicit SEED given) -- see run_test()'s docstring for why the
    # two are tracked independently rather than as a single seed.
    def _fmt_seed(s):
        return s if s is not None else "-"

    gen_width = max([len("GEN_SEED")] + [len(_fmt_seed(r[3])) for r in results])
    run_width = max([len("RUN_SEED")] + [len(_fmt_seed(r[4])) for r in results])
    header = (f"{'TEST'.ljust(width)}   RESULT   "
              f"{'GEN_SEED'.ljust(gen_width)}   {'RUN_SEED'.ljust(run_width)}   DETAIL")
    sep_width = len(header)

    print()
    print("=" * sep_width)
    print(f"testbench: {args.tb}")
    print("-" * sep_width)
    print(header)
    print("-" * sep_width)
    counts = {"PASS": 0, "FAIL": 0, "ERROR": 0}
    for test, outcome, detail, gen_seed, run_seed in results:
        counts[outcome] = counts.get(outcome, 0) + 1
        print(f"{test.ljust(width)}   {outcome:<6}   "
              f"{_fmt_seed(gen_seed).ljust(gen_width)}   "
              f"{_fmt_seed(run_seed).ljust(run_width)}   {detail}")
    print("=" * sep_width)
    total = len(results)
    print(f"{total} test(s): {counts['PASS']} passed, "
          f"{counts['FAIL']} failed, {counts['ERROR']} error(s)")

    # Exit non-zero unless everything ran and passed.
    sys.exit(0 if counts["PASS"] == total else 1)


if __name__ == "__main__":
    main()
