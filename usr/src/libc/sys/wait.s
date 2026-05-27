


.globl wait
wait:
		push {r4, lr}
		mov r4, r0
		mov ip, r7
		mov r7, #7
		svc #0
		mov r7, ip
		cmp r0, #0
		blt 1f
		cmp r4, #0
		strne r1, [r4]
		pop {r4, pc}
1:
		rsb r1, r0, #0
		ldr r2, =errno
		str r1, [r2]
		mvn r0, #0
		pop {r4, pc}
