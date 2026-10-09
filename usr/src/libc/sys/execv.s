.globl	execv
execv:
	ldr	r2, =environ
	ldr	r2, [r2]
	mov	ip, #59
	b	cerror
