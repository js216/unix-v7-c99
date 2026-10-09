.globl	getuid, geteuid
getuid:
	mov	ip, #24
	b	cerror
geteuid:
	push	{lr}
	bl	getuid
	mov	r0, r1
	pop	{pc}
