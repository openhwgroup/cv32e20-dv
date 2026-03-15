// Top level testbench for the CV32E20
// 
// Copyright 2025 Eclipse Foundation
// SPDX-License-Identifier: Apache-2.0 WITH SHL-0.51
//
// Copyright 2017 Embecosm Limited <www.embecosm.com>
// Copyright 2018 Robert Balas <balasr@student.ethz.ch>
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Contributor: Robert Balas <balasr@student.ethz.ch>
//              Jeremy Bennett <jeremy.bennett@embecosm.com>

`timescale 1ns/100ps

module tb_top
    #(parameter INSTR_RDATA_WIDTH = 32,
      parameter RAM_ADDR_WIDTH    = 22,
      parameter BOOT_ADDR         = 'h2000 // must be 256-byte aligned (cannot be 'h80)
     );

    const int CLK_PHASE_HI        = 5;
    const int CLK_PHASE_LO        = 5;
    const int CLK2NRESET_DELAY    = 1;
    const int RESET_ASSERT_CYCLES = 4;

    // clock and reset for tb
    logic                   core_clk;
    logic                   core_rst_n;

    // CPU control signals
    logic                   fetch_enable;

    // cycle counter
    int unsigned            cycle_cnt_q;

    // exit status flags
    logic                   tests_passed;
    logic                   tests_failed;
    logic                   exit_valid;
    logic [31:0]            exit_value;

    // strings for $display() and plusarg processing
    string id = "tb_top";
    string wave_file;

    // dumps waves
    initial begin
        if ($value$plusargs("wave_file=%s", wave_file)) begin
            $display("[%s] @ t=%0t: dumping waves to %s", id, $time, wave_file);
            $dumpfile(wave_file);
            $dumpvars(0, tb_top);
        end
    end

    // we either load the provided firmware or execute a small test program that
    // doesn't do more than an infinite loop with some I/O
    initial begin: load_prog
        automatic string test_program;
        automatic int prog_size = 6;

        if($value$plusargs("test_program=%s", test_program)) begin
            if($test$plusargs("verbose"))
                $display("[%s] @ t=%0t: loading test-program %0s", id, $time, test_program);
            $readmemh(test_program, cv32e20_tb_wrapper_inst.mm_ram_inst.dp_ram_inst.mem);
        end else begin
            $display("[%s] @ t=%0t: No test_program specified... terminating.", id, $time);
            end_of_sim();
        end
    end

    initial begin: clock_gen
        core_clk = 1'b1;
	// FIXME: using a forever loop here hangs Verilator
        repeat(10_000_000) begin
            #CLK_PHASE_HI core_clk = 1'b0;
            #CLK_PHASE_LO core_clk = 1'b1;
        end
    end: clock_gen
   

    // timing format, reset generation and parameter check
    initial begin
        $timeformat(-9, 0, "ns", 9);
        core_rst_n   = 1'b0; // assert reset
        fetch_enable = 1'b0; // deassert fetch-enable (for now)

        // hold in reset for a few cycles
        repeat (RESET_ASSERT_CYCLES) @(posedge core_clk);
        // start running
        #CLK2NRESET_DELAY core_rst_n = 1'b1;
        core_rst_n = 1'b1;
        if($test$plusargs("verbose")) begin
            $display("[%s] @ t=%0t: reset deasserted", id, $time);
        end

        // wait a few cycles
        repeat (RESET_ASSERT_CYCLES) @(posedge core_clk);
        // assert fetch-enable
        #CLK2NRESET_DELAY fetch_enable = 1'b1;
        if($test$plusargs("verbose")) begin
            $display("[%s] @ t=%0t: fetch-enable asserted", id, $time);
        end

        if ( !( (INSTR_RDATA_WIDTH == 128) || (INSTR_RDATA_WIDTH == 32) ) ) begin
         $fatal(2, "[%s] @ t=%0t: invalid INSTR_RDATA_WIDTH, choose 32 or 128", id, $time);
        end
    end

    // abort after n cycles, if we want to
    always_ff @(posedge core_clk, negedge core_rst_n) begin
        automatic int maxcycles;
        if($value$plusargs("maxcycles=%d", maxcycles)) begin
            if (~core_rst_n) begin
                cycle_cnt_q <= 0;
            end else begin
                cycle_cnt_q     <= cycle_cnt_q + 1;
                if (cycle_cnt_q >= maxcycles) begin
                    $fatal(2, "[%s] @ t=%0t: Simulation aborted due to maximum cycle limit", id, $time);
                end
            end
        end
    end

    // Check for virtual peripheral status flags that the test-program may (or
    // may not) use to indicate the end of a test.
    always_ff @(posedge core_clk) begin: vp_check
        if (tests_passed) begin
            $display("[%s] @ t=%0t: ALL TESTS PASSED", id, $time);
            end_of_sim();
        end
        if (tests_failed) begin
            $display("[%s] @ t=%0t: TEST(S) FAILED!", id, $time);
            end_of_sim();
        end
        if (exit_valid) begin
            if (exit_value == 0)
                $display("[%s] @ %0t: EXIT SUCCESS", id, $time);
            else
                $display("[%s] @ %0t: EXIT FAILURE: %d", id, $time, exit_value);
            end_of_sim();
        end
    end

    // End Of Simulation control:
    //   - If the test-program invokes the virtual peripheral status flags
    //     (see 'vp_check' block, above) then end_of_sim() is called and it
    //     will trigger the 'final' block.
    //   - If the test-program invokes the C stdlib macro EXIT_SUCCESS or
    //     EXIT_FAILURE, then the simulation process is terminated and
    //     end_of_sim() is never called.  In this case the 'final' block
    //     is used to display the end of simulation messages, if any.
    task end_of_sim();
        $finish;
    endtask

    final begin
        if (wave_file != "") begin
	    $display("[%s] @ t=%0t: waves written to %s", id, $time, wave_file);
	end
	$display("\n[%s] @ t=%0t: Verilator simulation ending...", id, $time);
    end

    // wrapper for cv32e20, the memory and virtual peripherals.
    cv32e20_tb_wrapper
        #(
          // Parameters used by TB
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH),
          .RAM_ADDR_WIDTH    (RAM_ADDR_WIDTH),
          .BOOT_ADDR         (BOOT_ADDR),
          .DM_HALTADDRESS    (32'h1A11_0800),
          // Parameters used by DUT
          .MHPMCounterNum    (10),
          .MHPMCounterWidth  (40),
          .RV32E             (1'b0),
          .RV32M             (2/*RV32MFast*/)
         )
    cv32e20_tb_wrapper_inst
        (
         .clk_i          ( core_clk     ),
         .rst_ni         ( core_rst_n   ),
         .fetch_enable_i ( fetch_enable ),
         .tests_passed_o ( tests_passed ),
         .tests_failed_o ( tests_failed ),
         .exit_valid_o   ( exit_valid   ),
         .exit_value_o   ( exit_value   )
        );

endmodule // tb_top
