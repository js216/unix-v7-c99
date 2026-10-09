.globl	close
.globl	cerror
close:
	mov	ip, #6
	b	cerror
