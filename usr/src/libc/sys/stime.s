.globl	stime
.globl	cerror
stime:
	ldm	r0, {r0, r1}
	mov	ip, #25
	b	cerror
