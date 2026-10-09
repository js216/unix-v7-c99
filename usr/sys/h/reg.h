/*
 * Location of the users' stored
 * registers relative to R0.
 * Usage is u.u_ar0[XX].
 */
#define	R0	(0)
#define	R1	(1)
#define	R2	(2)
#define	R3	(3)
#define	R4	(4)
#define	R5	(5)
#define	R6	(13)		/* user stack pointer */
#define	R7	(15)		/* user program counter */
#define	PC	(15)
#define	RPS	(16)		/* saved cpsr */

#define	TBIT	0		/* no PDP-11 trace bit on Arm */
