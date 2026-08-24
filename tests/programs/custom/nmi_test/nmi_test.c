/*
** NMI directed test (CV32E20).
**
** Confirms the DUT correctly takes a non-maskable interrupt (irq_nm_i,
** wired to irq_uvma[0] in uvmt_cv32e20_dut_wrap.sv) and returns cleanly.
**
** The NMI itself is injected by the testbench, not this program: run with
** +nmi_assert (see uvmt_cv32e20_general_purpose_test_c::nmi_assert(),
** which starts uvme_cv32e20_nmi_assert_c) to have the environment assert
** irq_uvma[0] once, after a bounded random delay, and hold it until acked.
**
** This program just busy-waits polling nmi_count (incremented by
** bsp/handlers.S's m_nmi_irq_handler each time it's entered -- see that
** file for why NMI needs a real, non-looping handler now) with a bounded
** local timeout, so a failure to take the NMI is reported as a clean
** TEST_FAILED rather than relying on the 100ms global watchdog.
*/

#include <stdio.h>
#include <stdint.h>

#include "cv32e20_dv.h"

/* Incremented by bsp/handlers.S's m_nmi_irq_handler. */
extern volatile uint32_t nmi_count;

/* Generous relative to the nmi_assert vseq's initial_delay distribution
** (bounded to [0:5000] interrupt-driver clock cycles, see
** uvme_cv32e20_nmi_assert_vseq.sv) plus ack handshake time. */
#define NMI_WAIT_TICKS 50000u

int main(void)
{
    uint32_t start_ticks;
    uint32_t before;

    printf("NMI directed test\n");

    before = nmi_count;
    start_ticks = MM_TICKS_REG;

    while (nmi_count == before) {
        if ((MM_TICKS_REG - start_ticks) > NMI_WAIT_TICKS) {
            printf("FAIL: NMI not taken within %u ticks (nmi_count still %u)\n",
                   NMI_WAIT_TICKS, nmi_count);
            TEST_FAILED;
            return 1;
        }
    }

    printf("NMI taken and handled (nmi_count=%u)\n", nmi_count);

    /* A second injected NMI (e.g. from -j or a later noise thread) landing
    ** after this point wouldn't be a failure -- only confirm forward
    ** progress resumed after the first one, don't over-constrain. */
    printf("Done\n");
    printf("SUCCESS\n");
    TEST_PASSED;
    return 0;
}
