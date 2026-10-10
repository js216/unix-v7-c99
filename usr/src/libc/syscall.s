.globl	cerror
cerror:
	push	{r7}
	mov	r7, ip
	svc	#0
	pop	{r7}
	bxcc	lr
	ldr	r2, =errno
	str	r0, [r2]
	mvn	r0, #0
	bx	lr
