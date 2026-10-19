.set	CBUFS, 300
.globl	_start, exit, __gnu_mcount_nc
_start:
	ldr	r0, [sp]
	add	r1, sp, #4
	add	r2, r1, r0, lsl #2
	add	r2, r2, #4
	ldr	r3, =environ
	str	r2, [r3]
	mov	r4, r0
	mov	r5, r1
	mov	r6, r2
	ldr	r0, =etext
	ldr	r1, =eprol
	sub	r0, r0, r1
	ldr	r1, =6+4*CBUFS
	add	r7, r1, r0, lsr #3
	lsl	r0, r7, #1
	bl	sbrk
	cmn	r0, #1
	beq	nospace
	mov	r2, r0
	mov	r3, r7
	mov	ip, #CBUFS
	str	ip, [sp, #-8]!
	ldr	r0, =eprol
	ldr	r1, =etext
	bl	monitor
	add	sp, sp, #8
	mov	r0, r4
	mov	r1, r5
	mov	r2, r6
	bl	main
	bl	exit
nospace:
	mov	r0, #2
	ldr	r1, =msg
	mov	r2, #msgend-msg
	bl	write
	mov	r0, #1
	bl	_exit

exit:
	mov	r4, r0
	bl	_cleanup
	mov	r0, #0
	bl	monitor
	mov	r0, r4
	bl	_exit

__gnu_mcount_nc:
	push	{r0, r1, r2, r3, lr}
	mov	r0, lr
	bl	mcount
	pop	{r0, r1, r2, r3, ip}
	pop	{lr}
	bx	ip
eprol:

.data
msg:	.ascii	"No space for monitor buffer\n"
msgend:
.comm	environ, 4
