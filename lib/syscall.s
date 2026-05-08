.globl syscall3
syscall3:
	mov ip, r7
	mov r7, r0
	mov r0, r1
	mov r1, r2
	mov r2, r3
	svc #0
	mov r7, ip
	bx lr

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
