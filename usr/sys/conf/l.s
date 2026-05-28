.globl _start
.globl vectors
.globl run_user
.globl return_frame
.globl mmu_on
.globl dmbsy
.globl irq_enable
.globl spl0
.globl spl1
.globl spl5
.globl spl6
.globl spl7
.globl splx
.globl cntfrq_get
.globl cntv_tval_set
.globl cntv_ctl_set
.globl main
USTACK = 0x000f0000
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

	mrs r0, cpsr
	bic r1, r0, #0x1f
	orr r1, r1, #0xd2
	msr cpsr_c, r1
	ldr sp, =irq_stack_top
	msr cpsr_c, r0

	bl main
	dsb ish
	isb
	mov r0, #0
	ldr r1, =USTACK
	bl run_user
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
	cpsid i
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
	bic r0, r0, #0x1f
	orr r0, r0, #0x10
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

irq_entry:
	sub lr, lr, #4
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r12}
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov r3, sp
	mov r4, lr
	msr cpsr_c, r1
	str r3, [sp, #52]
	str r4, [sp, #56]
	mov r0, sp
	bl clock_irq_handler
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

badtrap:
	bl panictrap
	b badtrap

undef_entry:
	sub lr, lr, #4
	mov ip, #4
	b user_trap_common
pabort_entry:
	sub lr, lr, #4
	mov ip, #11
	b user_trap_common
dabort_entry:
	sub lr, lr, #8
	mov ip, #11

user_trap_common:
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r12}
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov r3, sp
	mov r4, lr
	msr cpsr_c, r1
	str r3, [sp, #52]
	str r4, [sp, #56]
	mov r0, ip
	mov r1, sp
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

return_frame:
	mov ip, r0
	ldr r1, [r0, #64]
	bic r1, r1, #0x1f
	orr r1, r1, #0x10
	msr spsr_cxsf, r1
	ldr r3, [r0, #52]
	ldr r4, [r0, #56]
	mrs r1, cpsr
	bic r2, r1, #0x1f
	orr r2, r2, #0x1f
	msr cpsr_c, r2
	mov sp, r3
	mov lr, r4
	msr cpsr_c, r1
	ldr lr, [ip, #60]
	ldmia ip, {r0-r11}
	ldr ip, [ip, #48]
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

irq_enable:
	cpsie i
	bx lr

spl0:
	mrs r0, cpsr
	ldr r1, =irq_ready
	ldr r1, [r1]
	cmp r1, #0
	bxeq lr
	cpsie i
	bx lr

spl1:
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

cntv_tval_set:
	mcr p15, 0, r0, c14, c3, 0
	isb
	bx lr

cntv_ctl_set:
	mcr p15, 0, r0, c14, c3, 1
	isb
	bx lr

.section .stack
.balign 8
stack_bottom:
	.space 8192
.globl stack_top
stack_top:
.balign 8
irq_stack_bottom:
	.space 4096
irq_stack_top:
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

resume:
	ldmia	r1, {r4-r11}
	ldr	sp, [r1, #32]
	ldr	lr, [r1, #36]
	mov	r0, #1
	bx	lr
	.size	resume, .-resume
