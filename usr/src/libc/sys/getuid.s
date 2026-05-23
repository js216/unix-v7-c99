






.globl getuid
getuid:
	mov ip, r7
	mov r7, #24
	svc #0
	mov r7, ip
	bx lr
.globl geteuid
geteuid:
	mov ip, r7
	mov r7, #24
	svc #0
	mov r7, ip
	mov r0, r1
	bx lr
