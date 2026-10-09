.globl setjmp
setjmp:
	stmia r0, {r4-r11, sp, lr}
	mov r0, #0
	bx lr

.globl longjmp
longjmp:
	ldmia r0, {r4-r11, sp, lr}
	movs r0, r1
	moveq r0, #1
	bx lr
