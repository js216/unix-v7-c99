@ Machine routines called by the C kernel (the v7 conf/mch.s role).
@ Low-core vectors and trap/interrupt entry live in l.s; this file holds
@ the assembly primitives the portable kernel invokes: the context switch
@ (save/resume), MMU enable, interrupt control, and timer accessors.

	.syntax unified
	.arch armv7-a
	.text

	.globl mmu_on
	.globl dmbsy
	.globl irq_enable
	.globl intr_enable
	.globl intr_disable
	.globl intr_restore
	.globl cntfrq_get
	.globl cntv_tval_set
	.globl cntv_ctl_set
	.globl save
	.globl resume

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

irq_enable:
	cpsie i
	bx lr

intr_enable:
	mrs r0, cpsr
	ldr r1, =irq_ready
	ldr r1, [r1]
	cmp r1, #0
	bxeq lr
	cpsie i
	bx lr

intr_disable:
	mrs r0, cpsr
	cpsid i
	bx lr

intr_restore:
	tst r0, #0x80
	bne 1f
	ldr r1, =irq_ready
	ldr r1, [r1]
	cmp r1, #0
	bxeq lr
	cpsie i
	bx lr
1:
	cpsid i
	bx lr

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

	.type	save, %function
save:
	stmia	r0, {r4-r11}
	str	sp, [r0, #32]
	str	lr, [r0, #36]
	mov	r0, #0
	bx	lr
	.size	save, .-save

@ resume(int p_addr, int *label): switch the UBASE u-area window to the
@ new process's image (the KISA6 trick), then restore callee regs+sp+pc
@ from label.  label is a UBASE-window VA, so after the window switch it
@ reads the NEW process's saved context.  IRQs masked across the switch;
@ no stack use between the remap and the sp reload.
	.type	resume, %function
resume:
	cpsid	i
	ldr	r2, =uarea_l2		@ kernel VA of the u-area L2 (PA==VA)
	ldr	r3, =0x44000000		@ COREBASE
	add	r3, r3, r0, lsl #6	@ CLKADDR(p_addr) = phys u-area base
	orr	r3, r3, #0x12		@ PG_KRW
	str	r3, [r2, #0]
	add	r3, r3, #0x1000
	str	r3, [r2, #4]
	add	r3, r3, #0x1000
	str	r3, [r2, #8]
	add	r3, r3, #0x1000
	str	r3, [r2, #12]
	dsb	ish
	mov	r3, #0
	mcr	p15, 0, r3, c8, c7, 0	@ TLBIALL
	dsb	ish
	isb
	ldmia	r1, {r4-r11}
	ldr	sp, [r1, #32]
	ldr	lr, [r1, #36]
	mov	r0, #1
	bx	lr
	.size	resume, .-resume
	.ltorg
