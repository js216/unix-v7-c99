.globl dmbsy, spl0, spl1, spl5, spl6, spl7, splx
.globl cntfrq_get, cntvct_get, cntv_cval_set, cntv_ctl_set, save, resume, dcflush
.globl arm_sync_icache, tlbflush, ttbset, idle, waitloc, savfp, restfp, dfar, dfsr
.globl fubyte, subyte, fuword, suword, copyin, copyout, nofault
.globl kl3u

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
	ldr r2, =kl3u+256*8
	lsl r3, r0, #12
	movw ip, #0x703
	orr r3, r3, ip
	str r3, [r2, #0]
	add r3, r3, #0x1000
	str r3, [r2, #8]
	dsb ish
	ldr r3, =u
	mcr p15, 0, r3, c8, c7, 3
	add r3, r3, #0x1000
	mcr p15, 0, r3, c8, c7, 3
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
	mrc p15, 0, r2, c0, c0, 1
	lsr r2, r2, #16
	and r2, r2, #0xf
	mov r3, #4
	lsl r2, r3, r2
	add r1, r0, r1
	sub r3, r2, #1
	bic r0, r0, r3
1:	cmp r0, r1
	bhs 2f
	mcr p15, 0, r0, c7, c11, 1
	add r0, r0, r2
	b 1b
2:	dsb ish
	mov r0, #0
	mcr p15, 0, r0, c7, c5, 0
	mcr p15, 0, r0, c7, c5, 6
	dsb ish
	isb
	bx lr

tlbflush:
	mov r0, #0
	dsb ish
	mcr p15, 0, r0, c8, c7, 0
	mcr p15, 0, r0, c7, c5, 6
	dsb ish
	isb
	bx lr

ttbset:
	mov r1, #0
	dsb ish
	mcrr p15, 0, r0, r1, c2
	isb
	mcr p15, 0, r1, c8, c7, 2
	mcr p15, 0, r1, c7, c5, 6
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
	bx lr

savfp:
	vmrs r1, fpscr
	str r1, [r0], #8
	vstmia r0!, {d0-d15}
	vstmia r0, {d16-d31}
	bx lr

restfp:
	ldr r1, [r0], #8
	vmsr fpscr, r1
	vldmia r0!, {d0-d15}
	vldmia r0, {d16-d31}
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
.balign 4096
kl3u:
	.space 4096
