.globl	chmod
.globl	cerror
chmod:
	mov	ip, #15
	b	cerror
