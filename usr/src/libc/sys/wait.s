.globl	wait
wait:
	push	{r0, lr}
	mov	ip, #7
	bl	cerror
	pop	{r2, lr}
	bxcs	lr
	cmp	r2, #0
	strne	r1, [r2]
	bx	lr
