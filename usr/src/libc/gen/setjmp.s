.globl setjmp
setjmp:
	stmia r0, {r4-r11, sp, lr}
	mov r0, #0
	bx lr

.globl longjmp
longjmp:
	ldmia r0, {r4-r11, sp, lr}
	mov r0, r1
	cmp r0, #0
	moveq r0, #1
	bx lr
