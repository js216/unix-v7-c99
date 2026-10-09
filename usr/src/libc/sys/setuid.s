.globl	setuid
.globl	cerror
setuid:
	mov	ip, #23
	b	cerror
