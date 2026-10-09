.globl	fork
.globl	cerror
fork:
	mov	ip, #2
	b	cerror
