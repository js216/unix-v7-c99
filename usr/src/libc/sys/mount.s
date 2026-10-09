.globl	mount
.globl	cerror
mount:
	mov	ip, #21
	b	cerror
