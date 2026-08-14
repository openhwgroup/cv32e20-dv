Tool-specific Makefiles for the CORE-V-VERIF UVM Verification Environment
==================================
This directory contains a set of simulator-specific Makefiles.
The Makefile selected is controlled by the `CV_SIMULATOR` shell environment variable.
For more information see Makefiles in [../README](../README.md#makefiles).

## Coverage "holes" reports (`vsim.mk`)

`cov_holes` and `cov_holes_details` report only what's *not* fully covered,
omitting any instance/coverage-type that's already at or above
`COV_HOLES_THRESHOLD` (default 100):

- `cov_holes` — compact: just the remaining coverage percentages, no source.
- `cov_holes_details` — same filtering, plus full source-line detail for
  whatever's still incomplete.

Both accept the same `TEST=`/`MERGE=YES`/`COV_INSTANCE=` options as `cov`,
and write to `<COV_DIR>/cov_report/cov_holes[_details]`. See
`docs/COVERAGE-MAKE-TARGETS.md` for the full set of coverage targets.
