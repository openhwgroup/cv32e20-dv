/*
* Copyright 2019 ETH Zürich and University of Bologna
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

/*
* Copyright 2020 Embecosm
* Copyright 2022 OpenHW Group
* SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
*/

/* Exception codes */
#define EXCEPTION_ILLEGAL_INSN 2
#define EXCEPTION_BREAKPOINT 3
#define EXCEPTION_ECALL_M 11

.section .text.handlers
.global __no_irq_handler
.global u_sw_irq_handler
.global m_software_irq_handler
.global m_timer_irq_handler
.global m_external_irq_handler
.global m_fast0_irq_handler
.global m_fast1_irq_handler
.global m_fast2_irq_handler
.global m_fast3_irq_handler
.global m_fast4_irq_handler
.global m_fast5_irq_handler
.global m_fast6_irq_handler
.global m_fast7_irq_handler
.global m_fast8_irq_handler
.global m_fast9_irq_handler
.global m_fast10_irq_handler
.global m_fast11_irq_handler
.global m_fast12_irq_handler
.global m_fast13_irq_handler
.global m_fast14_irq_handler
.global m_fast15_irq_handler
.global m_nmi_irq_handler

.weak __no_irq_handler
.weak u_sw_irq_handler
.weak m_software_irq_handler
.weak m_timer_irq_handler
.weak m_external_irq_handler
.weak m_fast0_irq_handler
.weak m_fast1_irq_handler
.weak m_fast2_irq_handler
.weak m_fast3_irq_handler
.weak m_fast4_irq_handler
.weak m_fast5_irq_handler
.weak m_fast6_irq_handler
.weak m_fast7_irq_handler
.weak m_fast8_irq_handler
.weak m_fast9_irq_handler
.weak m_fast10_irq_handler
.weak m_fast11_irq_handler
.weak m_fast12_irq_handler
.weak m_fast13_irq_handler
.weak m_fast14_irq_handler
.weak m_fast15_irq_handler
.weak m_nmi_irq_handler

/* exception handling */
__no_irq_handler:
	la a0, no_exception_handler_msg
	jal ra, puts
	j __no_irq_handler

m_software_irq_handler:
	j __no_irq_handler

m_timer_irq_handler:
	j __no_irq_handler

m_external_irq_handler:
	j __no_irq_handler

m_fast0_irq_handler:
	j __no_irq_handler

m_fast1_irq_handler:
	j __no_irq_handler

m_fast2_irq_handler:
	j __no_irq_handler

m_fast3_irq_handler:
	j __no_irq_handler

m_fast4_irq_handler:
	j __no_irq_handler

m_fast5_irq_handler:
	j __no_irq_handler

m_fast6_irq_handler:
	j __no_irq_handler

m_fast7_irq_handler:
	j __no_irq_handler

m_fast8_irq_handler:
	j __no_irq_handler

m_fast9_irq_handler:
	j __no_irq_handler

m_fast10_irq_handler:
	j __no_irq_handler

m_fast11_irq_handler:
	j __no_irq_handler

m_fast12_irq_handler:
	j __no_irq_handler

m_fast13_irq_handler:
	j __no_irq_handler

m_fast14_irq_handler:
	j __no_irq_handler

m_fast15_irq_handler:
	j __no_irq_handler

m_nmi_irq_handler:
	/* Real NMI handler (unlike the other *_irq_handler stubs above, which
	   just loop forever): saves all caller-saved regs (NMI can interrupt
	   arbitrary code, same reasoning as u_sw_irq_handler below), logs
	   entry, increments nmi_count so a test can positively confirm the
	   NMI was taken and handled (not just silently missed), and mrets.
	   NMI exit is a plain mret, same as any other M-mode exception return
	   -- see cve2_controller.sv, nmi_mode_q is cleared on mret. */
	addi sp,sp,-64
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	sw a2, 12(sp)
	sw a3, 16(sp)
	sw a4, 20(sp)
	sw a5, 24(sp)
	sw a6, 28(sp)
	sw a7, 32(sp)
	sw t0, 36(sp)
	sw t1, 40(sp)
	sw t2, 44(sp)
	sw t3, 48(sp)
	sw t4, 52(sp)
	sw t5, 56(sp)
	sw t6, 60(sp)
	la a0, nmi_msg
	jal ra, puts
	la t0, nmi_count
	lw t1, 0(t0)
	addi t1, t1, 1
	sw t1, 0(t0)
	lw ra, 0(sp)
	lw a0, 4(sp)
	lw a1, 8(sp)
	lw a2, 12(sp)
	lw a3, 16(sp)
	lw a4, 20(sp)
	lw a5, 24(sp)
	lw a6, 28(sp)
	lw a7, 32(sp)
	lw t0, 36(sp)
	lw t1, 40(sp)
	lw t2, 44(sp)
	lw t3, 48(sp)
	lw t4, 52(sp)
	lw t5, 56(sp)
	lw t6, 60(sp)
	addi sp,sp,64
	mret

u_sw_irq_handler:
	/* While we are still using puts in handlers, save all caller saved
	   regs.  Eventually, some of these saves could be deferred.  */
	addi sp,sp,-64
	sw ra, 0(sp)
	sw a0, 4(sp)
	sw a1, 8(sp)
	sw a2, 12(sp)
	sw a3, 16(sp)
	sw a4, 20(sp)
	sw a5, 24(sp)
	sw a6, 28(sp)
	sw a7, 32(sp)
	sw t0, 36(sp)
	sw t1, 40(sp)
	sw t2, 44(sp)
	sw t3, 48(sp)
	sw t4, 52(sp)
	sw t5, 56(sp)
	sw t6, 60(sp)
	csrr t0, mcause
	li t1, EXCEPTION_ILLEGAL_INSN
	beq t0, t1, handle_illegal_insn
	li t1, EXCEPTION_ECALL_M
	beq t0, t1, handle_ecall
	li t1, EXCEPTION_BREAKPOINT
	beq t0, t1, handle_ebreak
	j handle_unknown

handle_ecall:
	jal ra, handle_syscall
	j end_handler_incr_mepc

handle_ebreak:
	/* TODO support debug handling requirements.  */
	la a0, ebreak_msg
	jal ra, puts
	j end_handler_incr_mepc

handle_illegal_insn:
	la a0, illegal_insn_msg
	jal ra, puts
	j end_handler_incr_mepc

handle_unknown:
	la a0, unknown_msg
	jal ra, puts
	/* We don't know what interrupt/exception is being handled, so don't
	   increment mepc.  */
	j end_handler_ret

end_handler_incr_mepc:
	csrr t0, mepc
	lb t1, 0(t0)
	li a0, 0x3
	and t1, t1, a0
	/* Increment mepc by 2 or 4 depending on whether the instruction at mepc
	   is compressed or not.  */
	bne t1, a0, end_handler_incr_mepc2
	addi t0, t0, 2
end_handler_incr_mepc2:
	addi t0, t0, 2
	csrw mepc, t0
end_handler_ret:
	lw ra, 0(sp)
	lw a0, 4(sp)
	lw a1, 8(sp)
	lw a2, 12(sp)
	lw a3, 16(sp)
	lw a4, 20(sp)
	lw a5, 24(sp)
	lw a6, 28(sp)
	lw a7, 32(sp)
	lw t0, 36(sp)
	lw t1, 40(sp)
	lw t2, 44(sp)
	lw t3, 48(sp)
	lw t4, 52(sp)
	lw t5, 56(sp)
	lw t6, 60(sp)
	addi sp,sp,64
	mret

.section .rodata
illegal_insn_msg:
	.string "CV32E20 BSP: illegal instruction exception handler entered\n"
ecall_msg:
	.string "CV32E20 BSP: ecall exception handler entered\n"
ebreak_msg:
	.string "CV32E20 BSP: ebreak exception handler entered\n"
unknown_msg:
	.string "CV32E20 BSP: unknown exception handler entered\n"
no_exception_handler_msg:
	.string "CV32E20 BSP: no exception handler installed\n"
nmi_msg:
	.string "CV32E20 BSP: NMI handler entered\n"

/* Incremented by m_nmi_irq_handler each time it's entered. Always present
   (zero-initialized, .bss) so any test can read it via
   `extern volatile uint32_t nmi_count;` to positively confirm an NMI was
   taken and handled, without every test needing to define it. */
.section .bss
.global nmi_count
.align 2
nmi_count:
	.word 0
