.globl	stat
.globl	cerror
stat:
	mov	ip, #18
	b	cerror
