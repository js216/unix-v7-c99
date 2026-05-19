/*
 * arch/swtch.s -- ARM EABI save/aretu/resume primitives.  Back v7's
 * setjmp-style sleep/swtch/newproc protocol in sys/slp.c.  label_t =
 * 10 ints: r4..r11 then sp, lr.  save returns 0; aretu/resume reloads
 * the regs and branches back through lr with r0=1.
 *
 * The PDP-11 v7 names were `savu' and `aretu'; we export both `save'
 * and `savu' for the C-reconstruction spelling.  swtch() is C in
 * sys/slp.c -- do not duplicate here.
 */

	.syntax unified
	.arch armv7-a
	.text

	.globl	save
	.globl	savu
	.type	save, %function
	.type	savu, %function

save:
savu:
	stmia	r0, {r4-r11}
	str	sp, [r0, #32]
	str	lr, [r0, #36]
	mov	r0, #0
	bx	lr
	.size	save, .-save
	.size	savu, .-savu

	.globl	aretu
	.type	aretu, %function

aretu:
	ldmia	r0, {r4-r11}
	ldr	sp, [r0, #32]
	ldr	lr, [r0, #36]
	mov	r0, #1
	bx	lr
	.size	aretu, .-aretu

	.globl	resume
	.type	resume, %function

/* resume(addr, lp): like aretu(lp), addr ignored on bare-metal ARM. */
resume:
	ldmia	r1, {r4-r11}
	ldr	sp, [r1, #32]
	ldr	lr, [r1, #36]
	mov	r0, #1
	bx	lr
	.size	resume, .-resume
