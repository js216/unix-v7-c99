.globl	chdir
.globl	cerror
chdir:
	mov	ip, #12
	b	cerror
