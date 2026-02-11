# UVM Tests for the CV32E20 UVM environment
In a UVM environment, all tests extend from `uvm_test`.
In CORE-V-VERIF environments, the DUT is a processor core and much of the "stimulus" comes from test-programs running on the core,
independant of the UVM environment.
The implication here is that there are many test-programs and few UVM tests.

- `uvmt_cv32_general_purpose_test.sv` is expected to be able to support almost all test-programs.

Additional UVM tests will be added as needed.
