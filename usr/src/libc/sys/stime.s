.globl	stime
.globl	cerror
stime:
	ldr	r0, [r0]
	mov	ip, #25
	b	cerror
