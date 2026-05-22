.globl profil
profil:
		mov ip, r7
		mov r7, #44
		svc #0
		mov r7, ip
		cmp r0, #0
		bxge lr
		rsb r1, r0, #0
		ldr r2, =errno
		str r1, [r2]
		mvn r0, #0
		bx lr
