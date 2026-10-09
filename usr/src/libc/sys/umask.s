.globl	umask
.globl	cerror
umask:
	mov	ip, #60
	b	cerror
