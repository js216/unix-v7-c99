.set BLK_KERN, 0x701
.globl _start, kl2, bootl1
_start:
	cpsid if
	mrc p15, 0, r0, c1, c0, 0	@ read SCTLR
	bic r0, r0, #(1 << 12)	@ I: icache off
	bic r0, r0, #(1 << 2)	@ C: dcache off
	bic r0, r0, #(1 << 11)	@ Z: branch prediction off
	bic r0, r0, #(1 << 13)	@ V: low vectors
	bic r0, r0, #1		@ M: MMU off
	mcr p15, 0, r0, c1, c0, 0	@ write SCTLR
	isb
	mov r0, #0
	mcr p15, 0, r0, c8, c7, 0	@ TLBIALL: TLB
	mcr p15, 0, r0, c7, c5, 0	@ ICIALLU: icache
	mcr p15, 0, r0, c7, c5, 6	@ BPIALL: branch predictor
	dsb
	isb
	adr r4, _start
	ldr r0, =_start
	sub r4, r4, r0
	ldr r0, =__bss_start
	ldr r1, =__bss_end
	add r0, r0, r4
	add r1, r1, r4
	mov r2, #0
1:
	cmp r0, r1
	strlo r2, [r0], #4
	blo 1b
	ldr r5, =kl2
	add r5, r5, r4
	ldr r0, =_start
	lsr r0, r0, #21
	ldr r1, =__bss_end
	sub r1, r1, #1
	lsr r1, r1, #21
	movw r3, #BLK_KERN
1:
	add ip, r4, r0, lsl #21
	orr ip, ip, r3
	ubfx r6, r0, #0, #9
	add r6, r5, r6, lsl #3
	str ip, [r6]
	add r0, r0, #1
	cmp r0, r1
	bls 1b
	ldr r6, =bootl1
	add r6, r6, r4
	adr r0, _start
	lsr r1, r0, #30
	lsl ip, r1, #30
	orr ip, ip, r3
	str ip, [r6, r1, lsl #3]
	mrc p15, 0, r1, c1, c0, 1
	orr r1, r1, #(1 << 6)
	mcr p15, 0, r1, c1, c0, 1
	isb
	mcr p15, 2, r2, c0, c0, 0
	isb
	mrc p15, 1, r0, c0, c0, 0
	and r1, r0, #7
	add r1, r1, #4
	movw r3, #0x3ff
	and r3, r3, r0, lsr #3
	clz ip, r3
	movw r7, #0x7fff
	and r7, r7, r0, lsr #13
1:	mov r8, r3
2:	lsl r9, r8, ip
	lsl r10, r7, r1
	orr r9, r9, r10
	mcr p15, 0, r9, c7, c6, 2
	subs r8, r8, #1
	bge 2b
	subs r7, r7, #1
	bge 1b
	dsb
	ldr r0, =0x4ff
	mcr p15, 0, r0, c10, c2, 0
	ldr r0, =0xb5023500
	mcr p15, 0, r0, c2, c0, 2
	mcrr p15, 0, r6, r2, c2
	mcrr p15, 1, r5, r2, c2
	isb
	mrc p15, 0, r0, c1, c0, 0	@ read SCTLR
	orr r0, r0, #1		@ M: MMU on
	orr r0, r0, #(1 << 2)	@ C: dcache on
	orr r0, r0, #(1 << 12)	@ I: icache on
	mcr p15, 0, r0, c1, c0, 0	@ write SCTLR
	isb
	ldr pc, =1f
1:
	ldr sp, =stack_top
	ldr r0, =vectors
	mcr p15, 0, r0, c12, c0, 0
	mrc p15, 0, r0, c1, c0, 2
	orr r0, r0, #(0xf << 20)
	mcr p15, 0, r0, c1, c0, 2
	isb
	mov r0, #(1 << 30)
	vmsr fpexc, r0
	bl machine_init
	mov sp, r0
	bl main
	mov r0, #0x10
	msr spsr_cxsf, r0
	mov lr, #0
	movs pc, lr

.balign 32
vectors:
	b _start
	b undef_entry
	b svc_entry
	b pabort_entry
	b dabort_entry
	b badtrap	@ reserved
	b irq_entry
	b badtrap	@ FIQ

svc_entry:
	srsdb sp!, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r14}^
	mov r0, sp
	cpsie i
	bl trap
	cpsid i
	b 2f

irq_entry:
	sub lr, lr, #4
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r14}^
	mov r5, lr
	mov r0, sp
	bl irq
	mov lr, r5
	ldr r0, [sp, #64]
	and r0, r0, #0x1f
	cmp r0, #0x10
	bne 2f
	ldr r0, =runrun
	ldrb r0, [r0]
	cmp r0, #0
	beq 2f
	mov r0, #0
	mov r2, #0
	b 1f

badtrap:
	cpsid if, #0x13
	bl panictrap
	b badtrap

undef_entry:
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r14}^
	mov r0, #4
	mov r2, #0
	b 1f
pabort_entry:
	sub lr, lr, #4
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r14}^
	mov r0, #11
	mov r2, #0
	b 1f
dabort_entry:
	sub lr, lr, #8
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r14}^
	ldr r0, =nofault
	ldr r0, [r0]
	cmp r0, #0
	strne r0, [sp, #60]
	bne 2f
	mov r0, #11
	mrc p15, 0, r2, c6, c0, 0
1:
	mov r1, sp
	cpsie i
	bl user_trap_handler
	cpsid i
2:
	ldmia sp, {r0-r14}^
	add sp, sp, #60
	rfeia sp!

.bss
.balign 8
	.space 8192
stack_top:
.balign 4096
kl2:
	.space 4096
bootl1:
	.space 32
