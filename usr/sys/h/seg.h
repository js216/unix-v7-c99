/*
 * v7 KT-11 segmentation-register addresses and access-mode bits.
 * UDSA (user D-space) and ka6 (kernel ISA reg 6) were used only by
 * sys/dev/bio.c::physio() (removed earlier), so they are gone.
 */

#define	UISD	((physadr)0177600)	/* first user I-space descriptor reg */
#define	UISA	((physadr)0177640)	/* first user I-space address reg */
#define	RO	02		/* access abilities */
#define	RW	06
#define	ED	010		/* extend direction */
#define	TX	020		/* Software: text segment */
#define	ABS	040		/* Software: absolute address */
