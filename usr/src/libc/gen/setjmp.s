.globl setjmp
setjmp:
	stmia r0!, {r4-r11, sp, lr}
	vstmia r0, {d8-d15}
	mov r0, #0
	bx lr

.globl longjmp
longjmp:
	ldmia r0!, {r4-r11, sp, lr}
	vldmia r0, {d8-d15}
	movs r0, r1
	moveq r0, #1
	bx lr
