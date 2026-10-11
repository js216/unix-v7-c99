.globl	time, ftime
time:
	push	{r0, lr}
	mov	ip, #13
	bl	cerror
	pop	{r2, lr}
	cmp	r2, #0
	stmne	r2, {r0, r1}
	bx	lr
ftime:
	mov	ip, #35
	b	cerror
