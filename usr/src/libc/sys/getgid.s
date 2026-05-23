


.globl getgid
getgid:
	mov ip, r7
	mov r7, #47
	svc #0
	mov r7, ip
	bx lr
.globl getegid
getegid:
	mov ip, r7
	mov r7, #47
	svc #0
	mov r7, ip
	mov r0, r1
	bx lr
