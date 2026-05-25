




.globl ptrace
ptrace:
		push {r4, r7}
		mov r4, r0
		mov r0, r3
		mov r3, r4
		mov r7, #26
		svc #0
		pop {r4, r7}
		cmp r0, #0
		bxge lr
		rsb r1, r0, #0
		ldr r2, =errno
		str r1, [r2]
		mvn r0, #0
		bx lr
