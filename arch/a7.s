.globl _start
.globl vectors
.globl run_user
.globl mmu_on
.globl dmbsy
.globl irq_enable
.globl irq_disable
.globl cntfrq_get
.globl cntv_tval_set
.globl cntv_ctl_set
.globl cntv_ctl_get
_start:

	ldr sp, =stack_top

	ldr r0, =vectors
	mcr p15, 0, r0, c12, c0, 0
	isb
	ldr r1, =__bss_end
	ldr r0, =__bss_start
	mov r2, #0
1:
	cmp r0, r1
	strlo r2, [r0], #4
	blo 1b

	/* Set up IRQ-mode stack so the IRQ handler has somewhere to push
	 * its banked return state (lr_irq, spsr_irq) via srsdb when an IRQ
	 * fires.  Boot starts in SVC mode with IRQs masked; switch to IRQ
	 * mode (keeping I+F masked), load sp_irq, then return to SVC mode. */
	mrs r0, cpsr
	bic r1, r0, #0x1f
	orr r1, r1, #0xd2    /* I=1, F=1, mode=IRQ(0x12) */
	msr cpsr_c, r1
	ldr sp, =irq_stack_top
	msr cpsr_c, r0       /* back to original (SVC) mode */

	bl main
halt:
	wfi
	b halt

.balign 32
vectors:
	b _start
	b undef_entry
	b svc_entry
	b pabort_entry
	b dabort_entry
	b badtrap
	b irq_entry
	b badtrap

svc_entry:
	sub sp, sp, #68
	stmia sp, {r0-r12}
	mov r0, sp
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov r3, sp
	mov r4, lr
	msr cpsr_c, r1
	str r3, [r0, #52]
	str r4, [r0, #56]
	mov r0, lr
	str r0, [sp, #60]
	mrs r0, spsr
	str r0, [sp, #64]
	mov r0, sp
	bl trap
	ldr r0, [sp, #64]
	msr spsr_cxsf, r0
	mov r0, sp
	ldr r3, [r0, #52]
	ldr r4, [r0, #56]
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov sp, r3
	mov lr, r4
	msr cpsr_c, r1
	ldmia sp, {r0-r12}
	ldr lr, [sp, #60]
	add sp, sp, #68
	movs pc, lr

/*
 * irq_entry -- ARM IRQ exception entry.
 *
 * On entry: CPU is in IRQ mode, lr_irq = preferred_return + 4, spsr_irq
 * holds caller's CPSR.  Interrupts (I bit) are masked.  We use the
 * dedicated irq_stack set up in _start to build a 17-word trap frame
 * compatible with svc_entry's layout, then drop to SVC mode to run the
 * C handler on the kernel's SVC stack.  Finally we restore the frame
 * and return via subs pc,lr,#4 which atomically restores CPSR.
 *
 * Frame layout (17 ints, same as svc_entry):
 *   r[0..12]   at offset 0..52
 *   r[13]=sp   at offset 52  (user/sys sp at time of interrupt)
 *   r[14]=lr   at offset 56  (user/sys lr at time of interrupt)
 *   r[15]=pc   at offset 60  (return address)
 *   r[16]=ps   at offset 64  (saved cpsr = spsr_irq)
 */
irq_entry:
	/* Adjust lr_irq to point at the instruction we want to resume on. */
	sub lr, lr, #4
	/* Push a partial frame onto the IRQ stack so we can move it.  We
	 * save r0-r3 and lr first so we have scratch registers.  */
	srsdb sp!, #0x13      /* Store return state (lr_irq, spsr_irq) onto SVC stack */
	cpsid if, #0x13       /* Switch to SVC mode, IRQ+FIQ masked */
	/* Now in SVC mode, sp = sp_svc.  Top of stack holds:
	 *    [sp+0] = saved pc (lr_irq-4)
	 *    [sp+4] = saved cpsr (spsr_irq)
	 * Build the full 17-int trap frame compatible with svc_entry's. */
	sub sp, sp, #60       /* room for r0..r14 (15 words = 60 bytes) below the srs pair */
	stmia sp, {r0-r12}    /* r0..r12 at offset 0..52 */
	/* Save the *interrupted* sp/lr.  In QEMU virt the interrupted mode
	 * is SVC (kernel) since user mode runs in SYS in this port.  But to
	 * handle either case, switch to SYS to read sp/lr of the interrupted
	 * context.  When the interrupted mode was already SVC the saved
	 * sp/lr are not needed for correctness (movs pc,lr restores nothing
	 * banked); for SYS-mode user code they are also banked the same
	 * way.  Use SYS-mode banked sp/lr as the "user-visible" pair, which
	 * matches svc_entry's convention. */
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f     /* SYS mode */
	msr cpsr_c, r2
	mov r3, sp
	mov r4, lr
	msr cpsr_c, r1        /* back to SVC */
	str r3, [sp, #52]     /* r[13] = sp_sys */
	str r4, [sp, #56]     /* r[14] = lr_sys */
	/* Hand the frame pointer to the C handler. */
	mov r0, sp
	bl clock_irq_handler
	/* Restore sp/lr banked to SYS mode if needed. */
	ldr r3, [sp, #52]
	ldr r4, [sp, #56]
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov sp, r3
	mov lr, r4
	msr cpsr_c, r1
	/* Restore r0..r12 */
	ldmia sp, {r0-r12}
	add sp, sp, #60
	/* sp now points at the {pc,cpsr} pair pushed by srsdb.  rfeia
	 * pops them and does the atomic return. */
	rfeia sp!

badtrap:
	bl panictrap
	b badtrap

/* ---------------- user-mode CPU exception entries ----------------
 * undef / prefetch-abort / data-abort traps from user mode should
 * post a signal to the current process and resume (or terminate).
 * The path is identical to svc_entry / irq_entry but we adjust lr
 * to point at the faulting instruction so user-mode signal handlers
 * can re-execute it (matching v7's trap.c approach where retaddr
 * is what the user PC will be set to on sigreturn).
 *
 * Each entry sets r0 = signal number, then jumps to user_trap_common
 * which builds the standard 17-int frame and calls user_trap_handler.
 *
 * lr adjustments per ARM ARM section A2.6:
 *   undef         : lr_und = faulting PC + 4 (Thumb +2) -> sub #4
 *   prefetch abort: lr_abt = faulting PC + 4              -> sub #4
 *   data abort    : lr_abt = faulting PC + 8              -> sub #8
 */
undef_entry:
	sub lr, lr, #4
	mov ip, #4		/* SIGILL */
	b user_trap_common
pabort_entry:
	sub lr, lr, #4
	mov ip, #11		/* SIGSEGV */
	b user_trap_common
dabort_entry:
	sub lr, lr, #8
	mov ip, #11		/* SIGSEGV */
	/* fall through */

user_trap_common:
	/* Mirror irq_entry's frame-build, but srs onto the SVC stack
	 * from the current mode (ABT or UND) using the same #0x13
	 * destination-mode encoding.  Then drop to SVC like irq_entry. */
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r12}
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f		/* SYS mode */
	msr cpsr_c, r2
	mov r3, sp
	mov r4, lr
	msr cpsr_c, r1			/* back to SVC */
	str r3, [sp, #52]
	str r4, [sp, #56]
	mov r0, ip			/* signo */
	mov r1, sp			/* trap frame ptr */
	bl user_trap_handler
	ldr r3, [sp, #52]
	ldr r4, [sp, #56]
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov sp, r3
	mov lr, r4
	msr cpsr_c, r1
	ldmia sp, {r0-r12}
	add sp, sp, #60
	rfeia sp!

run_user:
	mrs r2, cpsr
	bic r3, r2, #0x1f
	orr r3, r3, #0x1f
	msr cpsr_c, r3
	mov sp, r1
	msr cpsr_c, r2
	mov r3, #0x10
	msr spsr_cxsf, r3
	mov lr, r0
	movs pc, lr

mmu_on:
	mcr p15, 0, r0, c2, c0, 0
	mov r1, #1
	mcr p15, 0, r1, c3, c0, 0
	mov r1, #0
	mcr p15, 0, r1, c8, c7, 0
	mrc p15, 0, r1, c1, c0, 0
	orr r1, r1, #1
	mcr p15, 0, r1, c1, c0, 0
	isb
	bx lr

dmbsy:
	dmb sy
	bx lr

/*
 * CPSR-I (IRQ mask) control.  irq_enable() clears I (allows IRQs);
 * irq_disable() sets I (masks).  Both run from SVC mode.
 */
irq_enable:
	cpsie i
	bx lr

irq_disable:
	cpsid i
	bx lr

/*
 * ARM Generic Timer accessors.
 *
 *   CNTFRQ      : MRC p15, 0, <Rt>, c14, c0, 0  -- timer counter freq (Hz)
 *   CNTV_TVAL   : MCR/MRC p15, 0, <Rt>, c14, c3, 0
 *   CNTV_CTL    : MCR/MRC p15, 0, <Rt>, c14, c3, 1
 *
 * Writing CNTV_TVAL = N sets CNTV_CVAL = CNTVCT + N, so the timer fires
 * after N counter ticks.  CNTV_CTL bit0 = ENABLE, bit1 = IMASK, bit2 = ISTATUS.
 */
cntfrq_get:
	mrc p15, 0, r0, c14, c0, 0
	bx lr

cntv_tval_set:
	mcr p15, 0, r0, c14, c3, 0
	isb
	bx lr

cntv_ctl_set:
	mcr p15, 0, r0, c14, c3, 1
	isb
	bx lr

cntv_ctl_get:
	mrc p15, 0, r0, c14, c3, 1
	bx lr

.section .stack
.balign 8
stack_bottom:
	.space 8192
stack_top:
.balign 8
irq_stack_bottom:
	.space 4096
irq_stack_top:
