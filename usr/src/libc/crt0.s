.globl _start
_start:
	mov r0, sp
	bl _startc
	mov r7, #1
	svc #0
	b .
