.globl	umount
.globl	cerror
umount:
	mov	ip, #22
	b	cerror
