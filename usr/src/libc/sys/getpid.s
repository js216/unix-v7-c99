

.globl getpid
getpid:
	mov ip, r7
	mov r7, #20
	svc #0
	mov r7, ip
	ldr r2, =_last_ppid
	str r1, [r2]
	bx lr
.globl getppid
getppid:
	mov ip, r7
	mov r7, #20
	svc #0
	mov r7, ip
	mov r0, r1
	bx lr
.data
.globl _last_ppid
_last_ppid: .word 0
