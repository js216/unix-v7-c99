.globl mmu_on, dmbsy, spl0, spl1, spl5, spl6, spl7, splx
.globl cntfrq_get, cntvct_get, cntv_cval_set, cntv_ctl_set, save, resume, dcflush
.globl arm_sync_icache, idle, waitloc, savfp, dfar, dfsr
.globl fubyte, subyte, fuword, suword, copyin, copyout, nofault
.globl l1, user_l2, uarea_l2

mmu_on:
	push {r4, r5, r6, r7, r8, r9}
	mrc p15, 0, r1, c1, c0, 1
	orr r1, r1, #(1 << 6)
	mcr p15, 0, r1, c1, c0, 1
	isb
	orr r0, r0, #0x4a
	mcr p15, 0, r0, c2, c0, 0
	mov r1, #1
	mcr p15, 0, r1, c3, c0, 0
	mov r1, #0
	mcr p15, 2, r1, c0, c0, 0
	isb
	mrc p15, 1, r2, c0, c0, 0
	and r3, r2, #7
	add r3, r3, #4
	movw r4, #0x3ff
	and r4, r4, r2, lsr #3
	clz r5, r4
	movw r6, #0x7fff
	and r6, r6, r2, lsr #13
1:	mov r7, r4
2:	lsl r8, r7, r5
	lsl r9, r6, r3
	orr r8, r8, r9
	mcr p15, 0, r8, c7, c6, 2
	subs r7, r7, #1
	bge 2b
	subs r6, r6, #1
	bge 1b
	dsb
	mrc p15, 0, r1, c1, c0, 0
	orr r1, r1, #1
	orr r1, r1, #(1 << 2)
	orr r1, r1, #(1 << 12)
	mcr p15, 0, r1, c1, c0, 0
	isb
	pop {r4, r5, r6, r7, r8, r9}
	bx lr

dmbsy:
	dmb sy
	bx lr

spl0:
spl1:
	mrs r0, cpsr
	ldr r1, =irq_ready
	ldr r1, [r1]
	cmp r1, #0
	bxeq lr
	cpsie i
	bx lr

spl5:
spl6:
spl7:
	mrs r0, cpsr
	cpsid i
	bx lr

splx:
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

cntvct_get:
	isb
	mrrc p15, 1, r0, r1, c14
	bx lr

cntv_cval_set:
	mcrr p15, 3, r0, r1, c14
	isb
	bx lr

cntv_ctl_set:
	mcr p15, 0, r0, c14, c3, 1
	isb
	bx lr

save:
	stmia r0, {r4-r11}
	str sp, [r0, #32]
	str lr, [r0, #36]
	mov r0, #0
	bx lr

resume:
	cpsid i
	ldr r2, =uarea_l2
	lsl r3, r0, #12
	movw ip, #0x45e
	orr r3, r3, ip
	str r3, [r2, #0]
	add r3, r3, #0x1000
	str r3, [r2, #4]
	dsb ish
	mov r3, #0
	mcr p15, 0, r3, c8, c7, 0
	dsb ish
	isb
	ldmia r1, {r4-r11}
	ldr sp, [r1, #32]
	ldr r2, [r1, #36]
	bl spl0
	mov r0, #1
	bx r2

dcflush:
	mrc p15, 0, r2, c0, c0, 1
	lsr r2, r2, #16
	and r2, r2, #0xf
	mov r3, #4
	lsl r2, r3, r2
	add r1, r0, r1
	sub r3, r2, #1
	bic r0, r0, r3
1:	mcr p15, 0, r0, c7, c14, 1
	add r0, r0, r2
	cmp r0, r1
	blo 1b
	dsb
	bx lr

arm_sync_icache:
	mov r0, #0
	dsb ish
	mcr p15, 0, r0, c8, c7, 0
	dsb ish
	isb
	push {r4, r5, r6, r7}
	mcr p15, 2, r0, c0, c0, 0
	isb
	mrc p15, 1, r0, c0, c0, 0
	and r1, r0, #7
	add r1, r1, #4
	movw r2, #0x3ff
	and r2, r2, r0, lsr #3
	clz r3, r2
	movw r4, #0x7fff
	and r4, r4, r0, lsr #13
1:	mov r5, r2
2:	lsl r6, r5, r3
	lsl r7, r4, r1
	orr r6, r6, r7
	mcr p15, 0, r6, c7, c10, 2
	subs r5, r5, #1
	bge 2b
	subs r4, r4, #1
	bge 1b
	pop {r4, r5, r6, r7}
	mov r0, #0
	dsb ish
	mcr p15, 0, r0, c7, c5, 0
	mcr p15, 0, r0, c7, c5, 6
	dsb ish
	isb
	bx lr

fubyte:
	ldr r3, =nofault
	adr r2, uerr
	str r2, [r3]
	ldrbt r1, [r0]
	mov r0, r1
	b uok

subyte:
	ldr r3, =nofault
	adr r2, uerr
	str r2, [r3]
	strbt r1, [r0]
	mov r0, #0
	b uok

fuword:
	ldr r3, =nofault
	adr r2, uerr
	str r2, [r3]
	ldrt r1, [r0]
	mov r0, r1
	b uok

suword:
	ldr r3, =nofault
	adr r2, uerr
	str r2, [r3]
	strt r1, [r0]
	mov r0, #0
	b uok

copyin:
	ldr r3, =nofault
	adr ip, uerr
	str ip, [r3]
	orr ip, r0, r1
	orr ip, ip, r2
	tst ip, #3
	bne 2f
1:	subs r2, r2, #4
	blo 3f
	ldrt ip, [r0], #4
	str ip, [r1], #4
	b 1b
2:	subs r2, r2, #1
	blo 3f
	ldrbt ip, [r0], #1
	strb ip, [r1], #1
	b 2b

copyout:
	ldr r3, =nofault
	adr ip, uerr
	str ip, [r3]
	orr ip, r0, r1
	orr ip, ip, r2
	tst ip, #3
	bne 2f
1:	subs r2, r2, #4
	blo 3f
	ldr ip, [r0], #4
	strt ip, [r1], #4
	b 1b
2:	subs r2, r2, #1
	blo 3f
	ldrb ip, [r0], #1
	strbt ip, [r1], #1
	b 2b
3:	mov r0, #0
uok:
	mov r2, #0
	str r2, [r3]
	bx lr
uerr:
	mov r2, #0
	str r2, [r3]
	mvn r0, #0
	bx lr

idle:
	cpsie i
	wfi
1:	cpsid i
savfp:
	bx lr

dfar:
	mrc p15, 0, r0, c6, c0, 0
	bx lr

dfsr:
	mrc p15, 0, r0, c5, c0, 0
	bx lr

.data
waitloc:
	.word 1b

.bss
.balign 4
nofault:
	.space 4

.section .ddrbss,"aw",%nobits
.balign 16384
l1:
	.space 16384
user_l2:
	.space 1024
uarea_l2:
	.space 1024
