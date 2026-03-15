// Wrapper for a CV32E20 "core" testbench,
// containing CV32E20, Memory and virtual peripherals.
//
// Copyright 2025 Eclipse Foundation
// SPDX-License-Identifier: Apache-2.0 WITH SHL-0.51
//
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

module cv32e20_tb_wrapper
    #(parameter // Parameters used by TB
                INSTR_RDATA_WIDTH = 32,
                RAM_ADDR_WIDTH    = 20,
                BOOT_ADDR         = 'h80,
                DM_HALTADDRESS    = 32'h1A11_0800,
                HART_ID           = 32'h0000_0000,
                // Parameters used by DUT
                MHPMCounterNum    = 10,
                MHPMCounterWidth  = 40,
                RV32E             = 1'b0,
                RV32M             = 2 // RV32MFast
    ) (
     input logic         clk_i,
     input logic         rst_ni,
     input logic         fetch_enable_i,

     output logic        tests_passed_o,
     output logic        tests_failed_o,
     output logic [31:0] exit_value_o,
     output logic        exit_valid_o);

    // signals connecting core to memory
    logic                         instr_req;
    logic                         instr_gnt;
    logic                         instr_rvalid;
    logic [31:0]                  instr_addr;
    logic [INSTR_RDATA_WIDTH-1:0] instr_rdata;

    logic                         data_req;
    logic                         data_gnt;
    logic                         data_rvalid;
    logic [31:0]                  data_addr;
    logic                         data_we;
    logic [3:0]                   data_be;
    logic [31:0]                  data_rdata;
    logic [31:0]                  data_wdata;

    // signals to debug unit
    logic                         debug_req;

    // irq signals (not used)
    logic [0:31]                  irq;
    logic [0:4]                   irq_id_in;
    logic                         irq_ack;
    logic [0:4]                   irq_id_out;
    logic                         irq_sec;


    // interrupts (only timer for now)
    assign irq_sec     = '0;

    // instantiate the core
    cve2_top #(
               .MHPMCounterNum   (10),
               .MHPMCounterWidth (40),
               .RV32E            (1'b0),
               .RV32M            () // RV32MFast
             )
    cv32e20_top_inst
        (
         .clk_i                  ( clk_i                 ),
         .rst_ni                 ( rst_ni                ),

         .test_en_i              ( '0                    ), // enable all clock gates for testing
         .ram_cfg_i              ( '0                    ), // prim_ram_1p_pkg::ram_1p_cfg_t RAM_1P_CFG_DEFAULT),

         .hart_id_i              ( HART_ID               ),
         .boot_addr_i            ( BOOT_ADDR             ),

         .instr_req_o            ( instr_req             ),
         .instr_gnt_i            ( instr_gnt             ),
         .instr_rvalid_i         ( instr_rvalid          ),
         .instr_addr_o           ( instr_addr            ),
         .instr_rdata_i          ( instr_rdata           ),
         .instr_err_i            ( 1'b0                  ),

         .data_req_o             ( data_req              ),
         .data_gnt_i             ( data_gnt              ),
         .data_rvalid_i          ( data_rvalid           ),
         .data_we_o              ( data_we               ),
         .data_be_o              ( data_be               ),
         .data_addr_o            ( data_addr             ),
         .data_wdata_o           ( data_wdata            ),
         .data_rdata_i           ( data_rdata            ),
         .data_err_i             ( 1'b0                  ),

         // Interrupts verified in UVM environment
         .irq_software_i         (  1'b0                 ),
         .irq_timer_i            (  1'b0                 ),
         .irq_external_i         (  1'b0                 ),
         .irq_fast_i             ( 16'h0000              ),
         .irq_nm_i               (  1'b0                 ),       // non-maskeable interrupt

         .debug_req_i            ( debug_req             ),
         .dm_halt_addr_i         ( DM_HALTADDRESS        ),
	 .dm_exception_addr_i    ( DM_EXCEPTIONADDRESS   ),
         .crash_dump_o           (                       ),

         // CPU Control Signals
         .fetch_enable_i         ( fetch_enable_i        ),
         .core_sleep_o           (                       )
	 
       );

    // this handles read to RAM and memory mapped pseudo peripherals
    mm_ram
        #(.RAM_ADDR_WIDTH (RAM_ADDR_WIDTH),
          .INSTR_RDATA_WIDTH (INSTR_RDATA_WIDTH))
    mm_ram_inst
        (.clk_i          ( clk_i                                     ),
         .rst_ni         ( rst_ni                                    ),
         .dm_halt_addr_i ( DM_HALTADDRESS                            ),

         .instr_req_i    ( instr_req                                 ),
         .instr_addr_i   ( { {10{1'b0}},
                             instr_addr[RAM_ADDR_WIDTH-1:0]
                           }                                         ),
         .instr_rdata_o  ( instr_rdata                               ),
         .instr_rvalid_o ( instr_rvalid                              ),
         .instr_gnt_o    ( instr_gnt                                 ),

         .data_req_i     ( data_req                                  ),
         .data_addr_i    ( data_addr                                 ),
         .data_we_i      ( data_we                                   ),
         .data_be_i      ( data_be                                   ),
         .data_wdata_i   ( data_wdata                                ),
         .data_rdata_o   ( data_rdata                                ),
         .data_rvalid_o  ( data_rvalid                               ),
         .data_gnt_o     ( data_gnt                                  ),

         .irq_id_i       ( irq_id_in                                 ),
         .irq_ack_i      ( irq_ack                                   ),
         .irq_o          ( irq_id_out                                ),

         .debug_req_o    ( debug_req                                 ),

         .pc_core_id_i   ( /*cv32e20_core_i.pc_id*/'0                ),

         .tests_passed_o ( tests_passed_o                            ),
         .tests_failed_o ( tests_failed_o                            ),
         .exit_valid_o   ( exit_valid_o                              ),
         .exit_value_o   ( exit_value_o                              ));

endmodule // cv32e20_tb_wrapper
