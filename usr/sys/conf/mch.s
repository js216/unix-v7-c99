@ Machine routines called by the C kernel (the v7 conf/mch.s role).
@ Low-core vectors and trap/interrupt entry live in low.s; this file holds
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
	.globl cntfrq_set
	.globl cntv_tval_set
	.globl cntv_ctl_set
	.globl save
	.globl resume
	.globl dcflush

mmu_on:
	push {r4, r5, r6, r7, r8, r9}
	@ Cortex-A7: set ACTLR.SMP (bit 6) before enabling the caches.  Without it
	@ the core treats Shareable Normal memory (our cached DDR sections) as
	@ non-coherent, so cached writes to DDR are silently dropped on eviction.
	mrc p15, 0, r1, c1, c0, 1	@ ACTLR
	orr r1, r1, #(1 << 6)		@ SMP: join the inner-shareable coherency domain
	mcr p15, 0, r1, c1, c0, 1
	isb
	mcr p15, 0, r0, c2, c0, 0	@ TTBR0 = page table
	mov r1, #1
	mcr p15, 0, r1, c3, c0, 0	@ DACR: domain 0 = manager
	mov r1, #0
	mcr p15, 0, r1, c8, c7, 0	@ TLBIALL
	mcr p15, 0, r1, c7, c5, 0	@ ICIALLU: invalidate I-cache
	mcr p15, 0, r1, c7, c5, 6	@ BPIALL: invalidate branch predictor
	@ invalidate the whole L1 data cache by set/way before enabling it
	mov r1, #0
	mcr p15, 2, r1, c0, c0, 0	@ CSSELR = 0 (L1 data)
	isb
	mrc p15, 1, r2, c0, c0, 0	@ CCSIDR
	and r3, r2, #7
	add r3, r3, #4			@ r3 = log2(line bytes)
	movw r4, #0x3ff
	and r4, r4, r2, lsr #3		@ r4 = ways - 1
	clz r5, r4			@ r5 = way bit shift
	movw r6, #0x7fff
	and r6, r6, r2, lsr #13		@ r6 = sets - 1
1:	mov r7, r4			@ r7 = way counter
2:	lsl r8, r7, r5
	lsl r9, r6, r3
	orr r8, r8, r9			@ (way<<shift) | (set<<lineorder)
	mcr p15, 0, r8, c7, c6, 2	@ DCISW: invalidate D-cache line
	subs r7, r7, #1
	bge 2b
	subs r6, r6, #1
	bge 1b
	dsb
	mrc p15, 0, r1, c1, c0, 0	@ SCTLR
	orr r1, r1, #1			@ M:  MMU enable
	orr r1, r1, #(1 << 2)		@ C:  data cache enable
	orr r1, r1, #(1 << 12)		@ I:  instruction cache enable
	mcr p15, 0, r1, c1, c0, 0
	isb
	pop {r4, r5, r6, r7, r8, r9}
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

cntfrq_set:				@ CNTFRQ = r0 (system counter Hz)
	mcr p15, 0, r0, c14, c0, 0
	dsb
	isb
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
	ldr	r3, =corebase		@ board COREBASE (resolved in machdep.c)
	ldr	r3, [r3]
	add	r3, r3, r0, lsl #6	@ CLKADDR(p_addr) = phys u-area base
	orr	r3, r3, #0x12		@ kernel rw, UNCACHED: the window is remapped
					@ to a new PA each switch; uncached avoids
					@ stale cache lines aliasing the old VA
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

@ dcflush(addr, n): clean+invalidate the D-cache over [addr, addr+n) to the
@ point of coherency, so a DMA buffer is consistent with main memory before a
@ device reads it and after a device writes it.  Only the cache-incoherent
@ board (SDMMC IDMA) calls this; QEMU's virtio path is coherent and never does.
	.type	dcflush, %function
dcflush:
	mrc	p15, 0, r2, c0, c0, 1	@ CTR
	lsr	r2, r2, #16
	and	r2, r2, #0xf		@ DminLine = log2(words/line)
	mov	r3, #4
	lsl	r2, r3, r2		@ r2 = cache line size in bytes
	add	r1, r0, r1		@ r1 = end address
	sub	r3, r2, #1
	bic	r0, r0, r3		@ align start down to a line
1:	mcr	p15, 0, r0, c7, c14, 1	@ DCCIMVAC: clean+invalidate by MVA
	add	r0, r0, r2
	cmp	r0, r1
	blo	1b
	dsb
	bx	lr
	.size	dcflush, .-dcflush
	.ltorg
