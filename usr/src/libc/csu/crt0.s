.globl	_start
_start:
	ldr	r0, [sp]
	add	r1, sp, #4
	add	r2, r1, r0, lsl #2
	add	r2, r2, #4
	ldr	r3, =environ
	str	r2, [r3]
	bl	main
	bl	exit
	mov	r7, #1
	svc	#0
.comm	environ, 4
.comm	errno, 4
