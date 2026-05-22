.globl _start
_start:
	bl _startc
	mov r7, #1
	svc #0
	b .
