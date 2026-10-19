.globl	ptrace
ptrace:
	push	{r0}
	mov	r0, #0
	ldr	ip, =errno
	str	r0, [ip]
	pop	{r0}
	mov	ip, r0
	mov	r0, r3
	mov	r3, ip
	mov	ip, #26
	b	cerror
