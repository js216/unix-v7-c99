@ Run-time helpers which GCC calls for 64-bit integer division and for
@ conversion of 64-bit integers to floating point.  They use the base
@ procedure call standard: arguments and results in core registers.

.globl	__aeabi_uldivmod, __aeabi_ldivmod, __aeabi_l2d, __aeabi_l2f

@ r1:r0 / r3:r2 -> quotient r1:r0, remainder r3:r2
__aeabi_uldivmod:
	orrs	ip, r1, r3
	bne	1f
	udiv	ip, r0, r2
	mls	r2, ip, r2, r0
	mov	r0, ip
	mov	r1, #0
	mov	r3, #0
	bx	lr
1:
	push	{r4, r5, r6, lr}
	mov	r4, #0
	mov	r5, #0
	mov	r6, #64
2:
	adds	r0, r0, r0
	adcs	r1, r1, r1
	adcs	r4, r4, r4
	adc	r5, r5, r5
	subs	ip, r4, r2
	sbcs	lr, r5, r3
	movcs	r4, ip
	movcs	r5, lr
	orrcs	r0, r0, #1
	subs	r6, r6, #1
	bne	2b
	mov	r2, r4
	mov	r3, r5
	pop	{r4, r5, r6, pc}

@ Signed: the quotient is truncated toward zero, and the remainder
@ takes the sign of the dividend.
__aeabi_ldivmod:
	push	{r4, lr}
	asr	r4, r1, #31
	asr	ip, r3, #31
	eor	r0, r0, r4
	eor	r1, r1, r4
	subs	r0, r0, r4
	sbc	r1, r1, r4
	eor	r2, r2, ip
	eor	r3, r3, ip
	subs	r2, r2, ip
	sbc	r3, r3, ip
	eor	ip, ip, r4
	push	{r4, ip}
	bl	__aeabi_uldivmod
	pop	{r4, ip}
	eor	r0, r0, ip
	eor	r1, r1, ip
	subs	r0, r0, ip
	sbc	r1, r1, ip
	eor	r2, r2, r4
	eor	r3, r3, r4
	subs	r2, r2, r4
	sbc	r3, r3, r4
	pop	{r4, pc}

@ r1:r0 -> double in r1:r0.  The high word times 2^32 is exact, so
@ the sum is rounded once.
__aeabi_l2d:
	vmov	s0, r0
	vcvt.f64.u32	d1, s0
	vmov	s0, r1
	vcvt.f64.s32	d2, s0
	vldr	d0, two32
	vmla.f64	d1, d2, d0
	vmov	r0, r1, d1
	bx	lr

@ r1:r0 -> float in r0.  Through a double, the magnitude would be
@ rounded twice once it needs more than 53 bits; so its low 11 bits
@ are folded into bit 11 first, which leaves the value exact in a
@ double and still tells the second rounding whether anything was
@ below.
__aeabi_l2f:
	asr	ip, r1, #31
	eor	r0, r0, ip
	eor	r1, r1, ip
	subs	r0, r0, ip
	sbc	r1, r1, ip
	cmp	r1, #0x200000
	blo	1f
	lsls	r2, r0, #21
	lsr	r0, r0, #11
	lsl	r0, r0, #11
	orrne	r0, r0, #0x800
1:
	vmov	s0, r0
	vcvt.f64.u32	d1, s0
	vmov	s0, r1
	vcvt.f64.u32	d2, s0
	vldr	d0, two32
	vmla.f64	d1, d2, d0
	vcvt.f32.f64	s0, d1
	vmov	r0, s0
	and	ip, ip, #0x80000000
	eor	r0, r0, ip
	bx	lr

.balign	8
two32:
	.word	0, 0x41f00000
