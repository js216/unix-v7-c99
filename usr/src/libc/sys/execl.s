.globl	execl
execl:
	push	{r1, r2, r3}
	mov	r1, sp
	ldr	r2, =environ
	ldr	r2, [r2]
	mov	ip, #59
	push	{lr}
	bl	cerror
	pop	{lr}
	add	sp, sp, #12
	bx	lr
