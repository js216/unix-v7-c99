.globl	sbrk, brk
sbrk:
	ldr	r2, =nd
	ldr	r1, [r2]
	push	{r1, lr}
	add	r0, r1, r0
	bl	brk
	pop	{r1, lr}
	cmp	r0, #0
	movge	r0, r1
	bx	lr
brk:
	push	{r0, lr}
	mov	ip, #17
	bl	cerror
	pop	{r1, lr}
	cmp	r0, #0
	ldrge	r2, =nd
	strge	r1, [r2]
	bx	lr

.data
nd:	.word	end
