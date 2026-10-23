/*
 * Wiring which differs between MP135 boards. Pins are port, pin,
 * and alternate function, port A being 0. The DK board has its
 * console on UART4 (CONSOLE 4), at PD6 and PD8 with function 8,
 * and the PMIC's data line on PB9.
 */
#define	CONSOLE		2		/* USART2 */
#define	CONS_TX		5, 13, 7	/* PF13 */
#define	CONS_RX		3, 15, 1	/* PD15 */
#define	I2C4_SDA	1, 7		/* PB7 */
