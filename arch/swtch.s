/*
 * arch/swtch.s -- ARM EABI save/resume primitives.  Back v7's
 * setjmp-style sleep/swtch/newproc protocol in sys/slp.c.  label_t =
 * 10 ints: r4..r11 then sp, lr.  save() returns 0; resume() reloads
 * the regs and branches back through lr with r0=1.  swtch() is C in
 * sys/slp.c -- do not duplicate here.
 */

	.syntax unified
	.arch armv7-a
	.text

	.globl	save
	.type	save, %function

save:
	stmia	r0, {r4-r11}
	str	sp, [r0, #32]
	str	lr, [r0, #36]
	mov	r0, #0
	bx	lr
	.size	save, .-save

	.globl	resume
	.type	resume, %function

/* resume(addr, lp): addr is the PDP-11 swap-back map slot, ignored on
 * bare-metal ARM since processes are always resident. */
resume:
	ldmia	r1, {r4-r11}
	ldr	sp, [r1, #32]
	ldr	lr, [r1, #36]
	mov	r0, #1
	bx	lr
	.size	resume, .-resume
