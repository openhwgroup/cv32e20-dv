//
// Copyright 2020,2022 OpenHW Group
// Copyright 2020 Datum Technology Corporation
// Copyright 2020 Silicon Labs, Inc.
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://solderpad.org/licenses/
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
//


`ifndef __UVMT_CV32E20_TB_SV__
`define __UVMT_CV32E20_TB_SV__


/**
 * Module encapsulating the CV32E20 DUT wrapper, and associated SV interfaces.
 * Also provide UVM environment entry and exit points.
 */
`default_nettype none
module uvmt_cv32e20_tb;

   import uvm_pkg::*;
   import uvmt_cv32e20_pkg::*;
   import uvme_cv32e20_pkg::*;
   `ifndef FORMAL
   `ifdef USE_ISS_IMPERAS
   import rvviApiPkg::*;
   `endif
   `endif

`ifdef SET_NUM_MHPMCOUNTERS
   parameter int CORE_PARAM_NUM_MHPMCOUNTERS = `SET_NUM_MHPMCOUNTERS;
`else
   parameter int CORE_PARAM_NUM_MHPMCOUNTERS = 1;
`endif

   // ENV (testbench) parameters
   parameter int ENV_PARAM_INSTR_ADDR_WIDTH  = 32;
   parameter int ENV_PARAM_INSTR_DATA_WIDTH  = 32;
   parameter int ENV_PARAM_RAM_ADDR_WIDTH    = 22;

   // Capture regs for test status from Virtual Peripheral in dut_wrap.mem_i
   bit        tp;
   bit        tf;
   bit        evalid;
   bit [31:0] evalue;

   // Agent interfaces
   uvma_clknrst_if     clknrst_if          (); // clock and resets from the clknrst agent
   uvma_clknrst_if     clknrst_if_iss      ();
   uvma_debug_if       debug_if            ();
   uvma_interrupt_if   interrupt_if        (); // Interrupts
   uvma_interrupt_if   vp_interrupt_if     (); // Interrupts
   uvma_obi_memory_if  obi_memory_instr_if (.clk(clknrst_if.clk),
                                            .reset_n(clknrst_if.reset_n));
   uvma_obi_memory_if  obi_memory_data_if  (.clk(clknrst_if.clk),
                                            .reset_n(clknrst_if.reset_n));

   // DUT Wrapper Interfaces
   uvmt_cv32e20_vp_status_if       vp_status_if(.tests_passed(),
                                                 .tests_failed(),
                                                 .exit_valid(),
                                                 .exit_value()); // Status information generated by the Virtual Peripherals in the DUT WRAPPER memory.
   uvme_cv32e20_core_cntrl_if      core_cntrl_if(); // Static and quasi-static core control inputs.
   uvmt_cv32e20_core_status_if     core_status_if(.core_busy(),
                                                   .sec_lvl());     // Core status outputs

   // Step and compare interface
   uvmt_cv32e20_step_compare_if step_compare_if();
   uvmt_cv32e20_isa_covg_if     isa_covg_if();

  bind cve2_core
    uvma_rvfi_instr_if rvfi_instr_if(
                                .clk            ( clknrst_if.clk),
                                .reset_n        ( clknrst_if.reset_n)
                                );
        bind cve2_cs_registers
        uvma_rvfi_unified_csr_if#(4096,32) rvfi_csr_if(
                                .clk            ( clknrst_if.clk),
                                .reset_n        ( clknrst_if.reset_n)
        );

   // RVVI SystemVerilog Interface
   `ifndef FORMAL
   `ifdef USE_ISS
      rvviTrace #( .NHART(1), .RETIRE(1)) rvvi_if();
   `endif
   `endif

  /**
   * DUT WRAPPER instance:
   * This is an update of the riscv_wrapper.sv from PULP-Platform RI5CY project with
   * a few mods to bring unused ports from the CORE to this level using SV interfaces.
   */
   uvmt_cv32e20_dut_wrap  #(
                           )
                            dut_wrap (.*);

  bind uvmt_cv32e20_dut_wrap
    uvma_obi_memory_assert_if_wrp#(
      .ADDR_WIDTH(32),
      .DATA_WIDTH(32),
      .AUSER_WIDTH(0),
      .WUSER_WIDTH(0),
      .RUSER_WIDTH(0),
      .ID_WIDTH(0),
      .ACHK_WIDTH(0),
      .RCHK_WIDTH(0),
      .IS_1P2(0)
    ) obi_instr_memory_assert_i(.obi(obi_memory_instr_if));

  bind uvmt_cv32e20_dut_wrap
    uvma_obi_memory_assert_if_wrp#(
      .ADDR_WIDTH(32),
      .DATA_WIDTH(32),
      .AUSER_WIDTH(0),
      .WUSER_WIDTH(0),
      .RUSER_WIDTH(0),
      .ID_WIDTH(0),
      .ACHK_WIDTH(0),
      .RCHK_WIDTH(0),
      .IS_1P2(0)
    ) obi_data_memory_assert_i(.obi(obi_memory_data_if));

  // TODO: these are CV32E40P-specific interfaces.
  //       Replace with a CV32E20-specific version.
  // Bind in verification modules to the design
  //bind cv32e20_core
  // in step_compare defined:
  // CV32E20_CORE   $root.uvmt_cv32e20_tb.dut_wrap.cv32e20_top_i.core_i
  // but currently instanced as:
  // uvmt_cv32e20_tb.dut_wrap.cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i
  bind uvmt_cv32e20_dut_wrap
    uvmt_cv32e20_interrupt_assert interrupt_assert_i(.mcause_n(cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mcause_d),
                                                      .mip(cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mip),
                                                      .mie_q(cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mie_q),
                                                      .mie_n(cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mie_d),
                                                      .mstatus_mie(cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mstatus_q.mie),
                                                      .mtvec_mode_q(cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mtvec_q),
                                                      .if_stage_instr_rvalid_i(cv32e20_top_i.u_cve2_top.u_cve2_core.if_stage_i.instr_rvalid_i),
                                                      .if_stage_instr_rdata_i(cv32e20_top_i.u_cve2_top.u_cve2_core.if_stage_i.instr_rdata_i),
                                                      .id_stage_instr_valid_i(cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.instr_valid_i),
                                                      .id_stage_instr_rdata_i(cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.instr_rdata_i),
                                                   // .branch_taken_ex(cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.perf_branch_o),  // was branch_taken_ex
                                                      .branch_taken_ex(cv32e20_top_i.u_cve2_top.u_cve2_core.perf_tbranch),  // was branch_taken_ex
                                                      .ctrl_fsm_cs(cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.ctrl_fsm_cs),
                                                      .debug_mode_q(cv32e20_top_i.u_cve2_top.u_cve2_core.id_stage_i.controller_i.debug_mode_q),
                                                      .clk       (clknrst_if.clk),
                                                      .clk_i     (clknrst_if.clk),
                                                      .rst_ni    (clknrst_if.reset_n),
                                                      .irq_i     (dut_wrap.irq),
                                                      .irq_ack_o (dut_wrap.irq_ack),
                                                      .irq_id_o  (dut_wrap.irq_id),
                                                      .fetch_enable_i          (),
                                                      .debug_req_i             (),
                                                      .core_sleep_o            (),
                                                      .*);

   // Debug assertion and coverage interface
   uvmt_cv32e20_debug_cov_assert_if debug_cov_assert_if(
    .clk_i                   (clknrst_if.clk),
    .rst_ni                  (clknrst_if.reset_n),

    .fetch_enable_i          (),

    // External interrupt interface
    .irq_i                   (dut_wrap.irq),
    .irq_ack_o               (dut_wrap.irq_ack),
    .irq_id_o                (dut_wrap.irq_id),
    .mie_q                   (dut_wrap.cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.mie_q),

    .if_stage_instr_rvalid_i (),
    .if_stage_instr_rdata_i  (),
    .id_stage_instr_valid_i  (),
    .id_stage_instr_rdata_i  (),
    .id_stage_is_compressed  (),
    .id_stage_pc             (),
    .if_stage_pc             (),
    .is_decoding             (),
    .id_valid                (),
    //.ctrl_fsm_cs             (),
    .illegal_insn_i          (),
    .illegal_insn_q          (),
    .ecall_insn_i            (),

    .boot_addr_i             (),

    .debug_req_i             (),
    .debug_mode_q            (),
    .dcsr_q                  (),
    .depc_q                  (),
    .depc_n                  (),
    .dm_halt_addr_i          (),
    .dm_exception_addr_i     (),

    .mcause_q                (),
    .mtvec                   (),
    .mepc_q                  (),
    .tdata1                  (),
    .tdata2                  (),
    .trigger_match_i         (),

    .mcountinhibit_q         (),
    .mcycle                  (),
    .minstret                (),
    .inst_ret                (),
    .core_sleep_o            (),
    .fence_i                 (),

    .csr_access              (),
    .csr_op                  (),
    .csr_op_dec              (),
    .csr_addr                (),
    .csr_we_int              (),

    .is_wfi                  (),
    .in_wfi                  (),
    .dpc_will_hit            (),
    .addr_match              (),
    .is_ebreak               (),
    .is_cebreak              (),
    .is_dret                 (),
    .is_mulhsu               (),
    .pending_enabled_irq     (),
    .pc_set                  (),
    .branch_in_decode        ()
  );

  // Instantiate debug assertions
  // TODO: replace with CV32E20-specific DEBUG assertions
  uvmt_cv32e20_debug_assert u_debug_assert(/*.cov_assert_if(debug_cov_assert_if)*/);

  // IMPERAS DV
  `ifndef FORMAL
  `ifdef USE_ISS_IMPERAS
    uvmt_cv32e20_imperas_dv_wrap #(
    ) imperas_dv (rvvi_if);
  `endif
  `endif

  //                // Only drive haltreq if we have an external request
  //                // TODO: replace with ImperasDV
  //                //if (dut_wrap.cv32e20_wrapper_i.core_i.id_stage_i.controller_i.ctrl_fsm_cs inside {cv32e20_pkg::DBG_TAKEN_ID, cv32e20_pkg::DBG_TAKEN_IF} &&
  //                //    dut_wrap.cv32e20_wrapper_i.core_i.id_stage_i.controller_i.debug_req_pending) begin
  //                if (dut_wrap.cv32e20_wrapper_i.core_i.id_stage_i.controller_i.debug_req_pending) begin

  //                    debug_req_state <= DBG_TAKEN;
  //                    // Already in sync, assert halreq right away
  //                    if (count_retire == count_issue) begin
  //                        iss_wrap.io.haltreq <= 1'b1;
  //                    end
  //                end
  //            end
  //            DBG_TAKEN: begin
  //                // Assert haltreq when we are in sync
  //                if (count_retire == count_issue) begin
  //                    iss_wrap.io.haltreq <= 1'b1;
  //                    debug_req_state <= DRIVE_REQ;
  //                end
  //            end
  //            DRIVE_REQ: begin
  //                // Deassert haltreq when DM is observed
  //                if(iss_wrap.io.DM == 1'b1) begin
  //                    debug_req_state <= INACTIVE;
  //                end
  //            end
  //            default: begin
  //                debug_req_state <= INACTIVE;
  //            end
  //        endcase
  //    end
  //  end
  // // End of ISS WRAPPER instanitation and step-and-compare logic.
  /////////////////////////////////////////////////////////////////////////////

   /**
    * Test bench entry point.
    */
   initial begin : test_bench_entry_point

     // Specify time format for simulation (units_number, precision_number, suffix_string, minimum_field_width)
     $timeformat(-9, 3, " ns", 8);

     // Add interfaces handles to uvm_config_db
     uvm_config_db#(virtual uvma_debug_if                    )::set(.cntxt(null), .inst_name("*.env.debug_agent"),            .field_name("vif"),              .value(debug_if)                                   );
     uvm_config_db#(virtual uvma_clknrst_if                  )::set(.cntxt(null), .inst_name("*.env.clknrst_agent"),          .field_name("vif"),              .value(clknrst_if)                                 );
     uvm_config_db#(virtual uvma_interrupt_if                )::set(.cntxt(null), .inst_name("*.env.interrupt_agent"),        .field_name("vif"),              .value(interrupt_if)                               );
     uvm_config_db#(virtual uvma_obi_memory_if               )::set(.cntxt(null), .inst_name("*.env.obi_memory_instr_agent"), .field_name("vif"),              .value(obi_memory_instr_if)                        );
     uvm_config_db#(virtual uvma_obi_memory_if               )::set(.cntxt(null), .inst_name("*.env.obi_memory_data_agent"),  .field_name("vif"),              .value(obi_memory_data_if)                         );
     uvm_config_db#(virtual uvmt_cv32e20_vp_status_if       )::set(.cntxt(null), .inst_name("*"),                            .field_name("vp_status_vif"),     .value(vp_status_if)                               );
     uvm_config_db#(virtual uvme_cv32e20_core_cntrl_if      )::set(.cntxt(null), .inst_name("*"),                            .field_name("core_cntrl_vif"),    .value(core_cntrl_if)                              );
     uvm_config_db#(virtual uvmt_cv32e20_core_status_if     )::set(.cntxt(null), .inst_name("*"),                            .field_name("core_status_vif"),   .value(core_status_if)                             );
     uvm_config_db#(virtual uvmt_cv32e20_step_compare_if    )::set(.cntxt(null), .inst_name("*"),                            .field_name("step_compare_vif"),  .value(step_compare_if)                            );
     uvm_config_db#(virtual uvmt_cv32e20_isa_covg_if        )::set(.cntxt(null), .inst_name("*"),                            .field_name("isa_covg_vif"),      .value(isa_covg_if)                                );
     uvm_config_db#(virtual uvmt_cv32e20_debug_cov_assert_if)::set(.cntxt(null), .inst_name("*.env"),                        .field_name("debug_cov_vif"),     .value(debug_cov_assert_if)                        );
     uvm_config_db#(virtual uvmt_cv32e20_vp_status_if       )::set(.cntxt(null), .inst_name("*.env"),                        .field_name("vp_status_vif"),     .value(vp_status_if)                               );
     uvm_config_db#(virtual uvmt_cv32e20_isa_covg_if        )::set(.cntxt(null), .inst_name("*.env"),                        .field_name("isa_covg_vif"),      .value(isa_covg_if)                                );
     uvm_config_db#(virtual uvma_interrupt_if                )::set(.cntxt(null), .inst_name("*.env"),                        .field_name("intr_vif"),         .value(interrupt_if)                               );
     uvm_config_db#(virtual uvma_debug_if                    )::set(.cntxt(null), .inst_name("*.env"),                        .field_name("debug_vif"),        .value(debug_if)                                   );
     uvm_config_db#(virtual uvma_rvfi_instr_if               )::set(.cntxt(null), .inst_name("*.env.rvfi_agent"),             .field_name("instr_vif0"),       .value(dut_wrap.cv32e20_top_i.u_cve2_top.u_cve2_core.rvfi_instr_if));
     uvm_config_db#(virtual uvma_rvfi_unified_csr_if#(4096,32))::set(.cntxt(null), .inst_name("*.env.rvfi_agent"),             .field_name("csr_vif0"),        .value(dut_wrap.cv32e20_top_i.u_cve2_top.u_cve2_core.cs_registers_i.rvfi_csr_if));
     // TODO: fix this
     //uvm_config_db#(virtual RVVI_memory                      )::set(.cntxt(null), .inst_name("*.env"),                        .field_name("rvvi_memory_vif"),  .value(iss_wrap.ram.memory)                        );

     // Make the DUT Wrapper Virtual Peripheral's status outputs available to the base_test
     uvm_config_db#(bit      )::set(.cntxt(null), .inst_name("*"), .field_name("tp"),     .value(1'b0)        );
     uvm_config_db#(bit      )::set(.cntxt(null), .inst_name("*"), .field_name("tf"),     .value(1'b0)        );
     uvm_config_db#(bit      )::set(.cntxt(null), .inst_name("*"), .field_name("evalid"), .value(1'b0)        );
     uvm_config_db#(bit[31:0])::set(.cntxt(null), .inst_name("*"), .field_name("evalue"), .value(32'h00000000));

     // DUT and ENV parameters
     // TODO: the E40P env uses this, but it is not clear that the E20 ever will.
     //uvm_config_db#(int)::set(.cntxt(null), .inst_name("*"), .field_name("CORE_PARAM_PULP_XPULP"),       .value(CORE_PARAM_PULP_XPULP)      );

     // Run test
     uvm_top.enable_print_topology = 0; // ENV coders enable this as a debug aid
     uvm_top.finish_on_completion  = 1;
     uvm_top.run_test();
   end : test_bench_entry_point

   assign core_cntrl_if.clk = clknrst_if.clk;

   // Informational print message on loading of OVPSIM ISS to benchmark some elf image loading times
   // OVPSIM runs its initialization at the #1ns timestamp, and should dominate the initial startup time
   `ifndef FORMAL // Formal ignores initial blocks, avoids unnecessary warning
   // overcome race
   `ifdef USE_ISS_IMPERAS
   initial begin
     if ($test$plusargs("USE_ISS")) begin
       #0.9ns;
       imperas_dv.ref_init();
     end
   end
   `endif
   `endif


   // Capture the test status and exit pulse flags
   // TODO: put this logic in the vp_status_if (makes it easier to pass to ENV)
   always @(posedge clknrst_if.clk) begin
     if (!clknrst_if.reset_n) begin
       tp     <= 1'b0;
       tf     <= 1'b0;
       evalid <= 1'b0;
       evalue <= 32'h00000000;
     end
     else begin
       if (vp_status_if.tests_passed) begin
         tp <= 1'b1;
         uvm_config_db#(bit)::set(.cntxt(null), .inst_name("*"), .field_name("tp"), .value(1'b1));
       end
       if (vp_status_if.tests_failed) begin
         tf <= 1'b1;
         uvm_config_db#(bit)::set(.cntxt(null), .inst_name("*"), .field_name("tf"), .value(1'b1));
       end
       if (vp_status_if.exit_valid) begin
         evalid <= 1'b1;
         uvm_config_db#(bit)::set(.cntxt(null), .inst_name("*"), .field_name("evalid"), .value(1'b1));
       end
       if (vp_status_if.exit_valid) begin
         evalue <= vp_status_if.exit_value;
         uvm_config_db#(bit[31:0])::set(.cntxt(null), .inst_name("*"), .field_name("evalue"), .value(vp_status_if.exit_value));
       end
     end
   end


   /**
    * End-of-test summary printout.
    */
   final begin: end_of_test
      uvm_report_server  rs;
      int                err_count;
      int                warning_count;
      int                fatal_count;
      static bit         sim_finished = 0;

      rs            = uvm_top.get_report_server();
      err_count     = rs.get_severity_count(UVM_ERROR);
      warning_count = rs.get_severity_count(UVM_WARNING);
      fatal_count   = rs.get_severity_count(UVM_FATAL);

      void'(uvm_config_db#(bit)::get(null, "", "sim_finished", sim_finished));

      // Shutdown the Reference Model
      `ifdef USE_ISS_IMPERAS
      // Exit handler for ImperasDV
      void'(rvviRefShutdown());
      `endif

      // In most other contexts, calls to $display() in a UVM environment are
      // illegal. Here they are OK because the UVM environment has shut down
      // and we are merely dumping a summary to stdout.
      //@DVT_LINTER_WAIVER_START "MT20210811_3" disable SVTB.29.1.7
      $display("\n%m: *** Test Summary ***\n");

      if (sim_finished && (err_count == 0) && (fatal_count == 0)) begin
         $display("    PPPPPPP    AAAAAA    SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    PP    PP  AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP    PP  AA    AA  SS        SS        EE        DD    DD    ");
         $display("    PPPPPPP   AAAAAAAA   SSSSSS    SSSSSS   EEEEE     DD    DD    ");
         $display("    PP        AA    AA        SS        SS  EE        DD    DD    ");
         $display("    PP        AA    AA  SS    SS  SS    SS  EE        DD    DD    ");
         $display("    PP        AA    AA   SSSSSS    SSSSSS   EEEEEEEE  DDDDDDD     ");
         $display("    ----------------------------------------------------------");
         if (warning_count == 0) begin
           $display("                        SIMULATION PASSED                     ");
         end
         else begin
           $display("                 SIMULATION PASSED with WARNINGS              ");
         end
         $display("    ----------------------------------------------------------");
      end
      else begin
         $display("    FFFFFFFF   AAAAAA   IIIIII  LL        EEEEEEEE  DDDDDDD       ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FFFFF     AAAAAAAA    II    LL        EEEEE     DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA    II    LL        EE        DD    DD      ");
         $display("    FF        AA    AA  IIIIII  LLLLLLLL  EEEEEEEE  DDDDDDD       ");

         if (sim_finished == 0) begin
            $display("    --------------------------------------------------------");
            $display("                   SIMULATION FAILED - ABORTED              ");
            $display("    --------------------------------------------------------");
         end
         else begin
            $display("    --------------------------------------------------------");
            $display("                       SIMULATION FAILED                    ");
            $display("    --------------------------------------------------------");
         end
      end
      //@DVT_LINTER_WAIVER_END "MT20210811_3"
   end

endmodule : uvmt_cv32e20_tb
`default_nettype wire

`endif // __UVMT_CV32E20_TB_SV__
