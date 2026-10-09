.globl	time, ftime
time:
	push	{r0, lr}
	mov	ip, #13
	bl	cerror
	pop	{r1, lr}
	cmp	r1, #0
	strne	r0, [r1]
	bx	lr
ftime:
	mov	ip, #35
	b	cerror
