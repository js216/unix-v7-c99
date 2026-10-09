.globl _start
_start:
	cpsid if
	mrc p15, 0, r0, c1, c0, 0
	bic r0, r0, #(1 << 12)
	bic r0, r0, #(1 << 2)
	bic r0, r0, #(1 << 11)
	bic r0, r0, #(1 << 13)
	bic r0, r0, #1
	mcr p15, 0, r0, c1, c0, 0
	isb
	mov r0, #0
	mcr p15, 0, r0, c8, c7, 0
	mcr p15, 0, r0, c7, c5, 0
	mcr p15, 0, r0, c7, c5, 6
	dsb
	isb
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
	bl machine_init
	ldr sp, =0x4F002000
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
	b badtrap
	b irq_entry
	b badtrap

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
	ldr r0, [sp, #64]
	and r0, r0, #0x1f
	cmp r0, #0x10
	bne 1f
	ldr r0, =runrun
	ldrb r0, [r0]
	cmp r0, #0
	beq 1f
	mov r0, #0
	mov r1, sp
	bl user_trap_handler
	cpsid i
1:
	mov lr, r5
	b 2f

badtrap:
	bl panictrap
	b badtrap

undef_entry:
	sub lr, lr, #4
	mov ip, #4
	b 1f
pabort_entry:
	sub lr, lr, #4
	mov ip, #11
	b 1f
dabort_entry:
	sub lr, lr, #8
	mov ip, #11
1:
	srsdb sp!, #0x13
	cpsid if, #0x13
	sub sp, sp, #60
	stmia sp, {r0-r14}^
	mov r0, ip
	mov r1, sp
	bl user_trap_handler
2:
	ldmia sp, {r0-r14}^
	add sp, sp, #60
	rfeia sp!

.bss
.balign 8
	.space 8192
stack_top:
