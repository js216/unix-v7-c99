.globl	fstat
.globl	cerror
fstat:
	mov	ip, #28
	b	cerror
