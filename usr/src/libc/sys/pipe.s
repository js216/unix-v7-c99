



.globl pipe
pipe:
		mov ip, r7
		mov r3, r0
		mov r7, #42
		svc #0
		mov r7, ip
		cmp r0, #0
		blt 1f
		str r0, [r3]
		str r1, [r3, #4]
		mov r0, #0
		bx lr
1:
		rsb r1, r0, #0
		ldr r2, =errno
		str r1, [r2]
		mvn r0, #0
		bx lr
