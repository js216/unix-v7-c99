.globl	ptrace
ptrace:
	mov	ip, r0
	mov	r0, r3
	mov	r3, ip
	mov	ip, #26
	b	cerror
