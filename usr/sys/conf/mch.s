.set BLK_KERN, 0x701
.set PTE_TAB, 3
.set PGSHIFT, 12
.set PGSIZE, 4096
.set USIZE, 1
.globl dmbsy, intr_enable, intr_disable, intr_restore
.globl cntfrq_get, cntvct_get, cntv_cval_set, cntv_ctl_set
.globl save, resume
.globl dcinval, dcflush, arm_sync_icache, tlbflush, ttbset
.globl fubyte, subyte, fuword, suword, copyin, copyout, nofault
.globl idle, waitloc
.globl savfp, restfp
.globl dfar, dfsr
.globl kl3u

dmbsy:
	dmb sy
	bx lr

intr_enable:
	cpsie i
	bx lr

intr_disable:
	mrs r0, cpsr
	cpsid i
	bx lr

intr_restore:
	tst r0, #0x80
	bne 1f
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
	ldr r2, =kl3u
	lsl r3, r0, #PGSHIFT
	movw ip, #BLK_KERN|PTE_TAB
	orr r3, r3, ip
	mov r0, #USIZE
1:	str r3, [r2], #8
	add r3, r3, #PGSIZE
	subs r0, r0, #1
	bne 1b
	dsb ish
	ldr r3, =u
	mov r0, #USIZE
1:	mcr p15, 0, r3, c8, c7, 3
	add r3, r3, #PGSIZE
	subs r0, r0, #1
	bne 1b
	dsb ish
	isb
	ldmia r1, {r4-r11}
	ldr sp, [r1, #32]
	ldr r2, [r1, #36]
	bl intr_enable
	mov r0, #1
	bx r2

dcinval:
	cmp r1, #0
	bxeq lr
	mov r12, lr
	bl dline
1:	mcr p15, 0, r0, c7, c6, 1	@ DCIMVAC: invalidate line
	add r0, r0, r2
	cmp r0, r1
	blo 1b
	dsb
	bx r12

dcflush:
	cmp r1, #0
	bxeq lr
	mov r12, lr
	bl dline
1:	mcr p15, 0, r0, c7, c14, 1 @ DCCIMVAC: clean and invalidate line
	add r0, r0, r2
	cmp r0, r1
	blo 1b
	dsb
	bx r12

arm_sync_icache:
	cmp r1, #0
	bxeq lr
	mov r12, lr
	bl dline
1:	mcr p15, 0, r0, c7, c11, 1	@ DCCMVAU: clean line to PoU
	add r0, r0, r2
	cmp r0, r1
	blo 1b
	dsb ish
	mov r0, #0
	mcr p15, 0, r0, c7, c5, 0	@ ICIALLU
	mcr p15, 0, r0, c7, c5, 6	@ BPIALL
	dsb ish
	isb
	bx r12

dline:
	mrc p15, 0, r2, c0, c0, 1	@ CTR: cache type
	lsr r2, r2, #16
	and r2, r2, #0xf
	mov r3, #4
	lsl r2, r3, r2
	add r1, r0, r1
	sub r3, r2, #1
	bic r0, r0, r3
	bx lr

tlbflush:
	mov r0, #0
	dsb ish
	mcr p15, 0, r0, c8, c7, 0	@ TLBIALL
	mcr p15, 0, r0, c7, c5, 6	@ BPIALL
	dsb ish
	isb
	bx lr

ttbset:
	mov r1, #0
	dsb ish
	mcrr p15, 0, r0, r1, c2	@ TTBR0
	isb
	mcr p15, 0, r1, c8, c7, 2	@ TLBIASID
	mcr p15, 0, r1, c7, c5, 6	@ BPIALL
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
	wfi
	cpsie i
waitpc:	cpsid i
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
	mrc p15, 0, r0, c6, c0, 0	@ DFAR
	bx lr

dfsr:
	mrc p15, 0, r0, c5, c0, 0	@ DFSR
	bx lr

.data
waitloc:
	.word waitpc

.bss
.balign 4
nofault:
	.space 4

.section .ddrbss,"aw",%nobits
.balign 4096
kl3u:
	.space 4096
