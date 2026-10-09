.globl	getgid, getegid
getgid:
	mov	ip, #47
	b	cerror
getegid:
	push	{lr}
	bl	getgid
	mov	r0, r1
	pop	{pc}
