.globl syscall3
syscall3:
	mov ip, r7
	mov r7, r0
	mov r0, r1
	mov r1, r2
	mov r2, r3
	svc #0
	mov r7, ip
	cmp r0, #0
	bxge lr
	rsb r1, r0, #0
	ldr r2, =errno
	str r1, [r2]
	mvn r0, #0
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
