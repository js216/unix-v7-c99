.globl	pipe
pipe:
	push	{r0, lr}
	mov	ip, #42
	bl	cerror
	pop	{r2, lr}
	cmp	r0, #0
	bxlt	lr
	stmia	r2, {r0, r1}
	mov	r0, #0
	bx	lr
