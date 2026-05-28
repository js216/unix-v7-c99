/*
 * ARM user address layout and software segment bits.
 */

#define	RO	02		/* access abilities */
#define	RW	06
#define	ED	010		/* extend direction */
#define	TX	020		/* Software: text segment */
#define	ABS	040		/* Software: absolute address */

/*
 * User virtual memory layout.
 */
#define KERNBASE	0x40000000U

#define USERBASE	0x00000000U
#define USERPHYS	0x44000000U
#define USERSIZE	0x00100000U
#define UENTRY		0x00010000U
#define USTACK		0x000f0000U
#define UARGV		0x0000f000U
#define UARGLEN		3072
#define UENTRY_SIGTRAMP	0x0000fe00U
