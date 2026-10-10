.globl	fork, par_uid
fork:
	push	{r7}
	mov	r7, #2
	svc	#0
	b	1f
	pop	{r7}
	bxcc	lr
	ldr	r2, =errno
	str	r0, [r2]
	mvn	r0, #0
	bx	lr
1:
	pop	{r7}
	ldr	r1, =par_uid
	str	r0, [r1]
	mov	r0, #0
	bx	lr
.comm	par_uid, 4
