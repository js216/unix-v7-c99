.globl	dup, dup2
.globl	cerror
dup2:
	orr	r0, r0, #64
dup:
	mov	ip, #41
	b	cerror
