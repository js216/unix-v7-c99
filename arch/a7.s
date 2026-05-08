.globl _start
.globl vectors
.globl run_user
.globl mmu_on
.globl dmbsy
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

	bl main
halt:
	wfi
	b halt

.balign 32
vectors:
	b _start
	b badtrap
	b svc_entry
	b badtrap
	b badtrap
	b badtrap
	b badtrap
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

badtrap:
	bl panictrap
	b badtrap

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

.section .stack
.balign 8
stack_bottom:
	.space 8192
stack_top:
