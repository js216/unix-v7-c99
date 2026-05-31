/*
 *   STM32MP135 board description + bring-up
 *
 * The machine-dependent data + hook the shared machine_init() (machdep.c)
 * needs for the custom STM32MP135 PCB: the physical memory map (board_map[])
 * and clock_ddr_init(), which brings up the clocks and DDR before the MMU is
 * enabled.  machine_init() itself -- the page-table builder -- is shared with
 * QEMU, so a QEMU run exercises the same code that runs here.
 *
 * The ROM loads this kernel (FSBL) from SD into SYSRAM and jumps to _start
 * (conf/low.s).  Kernel runs in cached SYSRAM; user core + buffer cache live
 * in cached DDR; peripherals + GIC are Device.  DDR3-1066 register values are
 * verbatim from the board reference firmware (board.h).
 */
#include "../h/param.h"
#include "../h/seg.h"

void clock_init(void);
void ddr_init(void);
void cntfrq_set(unsigned int hz);	/* CP15 generic-timer frequency (mch.s) */

/* RCC + DDR controller/PHY + security blocks (board reference firmware) */
#define RCC		0x50000000U
#define PWR		0x50001000U
#define STGENC		0x5C008000U	/* system timer generator (counter) */
#define DDRCTRL		0x5A003000U
#define DDRPHYC		0x5A004000U
#define BSEC		0x5C005000U
#define TZC		0x5C006000U
#define R32(a)		(*(volatile unsigned int *)(a))

/* RCC registers used here (offsets verified against the board headers) */
#define RCC_OCENSETR	R32(RCC + 0x420)	/* oscillator enable (set-reg) */
#define RCC_OCRDYR	R32(RCC + 0x428)	/* oscillator ready */
#define RCC_STGENCKSELR	R32(RCC + 0x660)	/* STGEN kernel clock select */
#define RCC_APB5ENSETR	R32(RCC + 0x740)	/* APB5 clock enable (set-reg) */
#define HSEON		0x00000100U		/* OCENSETR/OCRDYR bit 8 */
#define HSERDY		0x00000100U
#define STGENCEN	0x00100000U		/* APB5ENSETR bit 20 */
#define STGENSRC_HSE	0x00000001U		/* STGENCKSELR field = HSE */
#define HSE_HZ		24000000U		/* board crystal */
/* PLL2 (DDR PHY clock); fields are value-1 per the RCC encoding */
#define RCC_RCK12SELR	R32(RCC + 0x480)	/* PLL1/2 reference clock select */
#define RCC_PLL2CR	R32(RCC + 0x4D0)
#define RCC_PLL2CFGR1	R32(RCC + 0x4D4)	/* DIVN[8:0], DIVM2[21:16] */
#define RCC_PLL2CFGR2	R32(RCC + 0x4D8)	/* DIVP[6:0], DIVQ[14:8], DIVR[22:16] */
#define RCC_PLL2FRACR	R32(RCC + 0x4DC)	/* FRACV[15:3], FRACLE[16] */
#define PLL12SRC_HSE	0x00000001U		/* RCK12SELR PLL12SRC = HSE */
#define PLL2_PLLON	0x00000001U
#define PLL2_RDY	0x00000002U
#define PLL2_DIVEN	0x00000070U		/* DIVP/Q/R output enables */
#define PLL2_FRACLE	0x00010000U
/* PLL4 (SDMMC1 kernel clock); same field encoding as PLL2 */
#define RCC_RCK4SELR	R32(RCC + 0x488)
#define RCC_PLL4CR	R32(RCC + 0x520)
#define RCC_PLL4CFGR1	R32(RCC + 0x524)
#define RCC_PLL4CFGR2	R32(RCC + 0x528)
#define RCC_SDMMC12CKSELR R32(RCC + 0x648)
#define PLL4SRC_HSE	0x00000001U		/* RCK4SELR PLL4SRC = HSE */
#define SDMMC1SRC_PLL4	0x00000002U		/* SDMMC12CKSELR SDMMC1SRC = PLL4 */

/*
 * Physical memory map: kernel SYSRAM and the DDR user-core/buffer window are
 * cached; the peripheral block and the GIC are Device.  Terminated by a zero
 * entry.  (SYSRAM 0x2FFE0000/128K sits in the 0x2FF00000 section; DDR is
 * 0xC0000000/512M.)
 */
struct memregion board_map[] = {
	{ 0x2FF00000U,	0x30000000U,	SEC_KERN },	/* SYSRAM: kernel */
	{ 0xC0000000U,	0xE0000000U,	0x00011402U },	/* DDR: Normal Non-cacheable Shareable (TEX=001,C=0,B=0) -- the SDMMC IDMA is non-coherent, so leaving the buffer cache + kernel tables uncached keeps CPU and DMA views consistent without per-line maintenance */
	{ 0x40000000U,	0x60000000U,	SEC_DEV },	/* APB/AHB peripherals */
	{ 0xA0000000U,	0xA0100000U,	SEC_DEV },	/* GIC */
	{ 0, 0, 0 }
};

/* Bring up clocks + DRAM before machine_init() enables the MMU. */
void
clock_ddr_init(void)
{
	clock_init();
	ddr_init();
}

/*
 * Clock tree: HSE 24 MHz feeds PLL1 (MPU), PLL2 (AXI + DDR @ 533 MHz), PLL4
 * (SDMMC); UART4 falls back on HSI, so the console can print at the ROM's
 * default clocks before this runs -- the first bench milestone.
 *
 * TODO(bench, #28): port the RCC PLL bring-up from the reference bootloader.
 * Source: stm32mp135_test_board/bootloader/drivers/stm32mp13xx_hal_rcc{,_ex}.c
 * (HAL_RCC_OscConfig + HAL_RCC_ClockConfig); the PLL coefficients live in that
 * board's RCC config.  PLL2_R must reach 533 MHz before ddr_init().  Cannot be
 * exercised in QEMU; iterate on the PCB watching UART4.
 *
 * Also program the system counter so the generic timer (clock.c) ticks: the
 * ROM leaves it dead because UNIX is the FSBL.  Per the bootloader's
 * handoff.S: select STGEN clock = HSE (RCC), enable + start STGEN, then set
 * CNTFRQ (CP15 c14,c0,0) = 24000000 so cntfrq_get() returns the true 24 MHz
 * and timer_reload (cntfrq/HZ) is correct -- otherwise there is no preemption.
 * On QEMU CNTFRQ is preset, which is why this is board-specific, not shared.
 */
void
clock_init(void)
{
	int timo;

	/* HSE on (24 MHz crystal); wait for it to stabilize. */
	RCC_OCENSETR = HSEON;
	for (timo = 100000; timo > 0 && !(RCC_OCRDYR & HSERDY); timo--)
		;

	/*
	 * System counter (STGEN): clock it from HSE, program 24 MHz, and start
	 * it so the Cortex-A7 generic timer (clock.c) advances -- the ROM leaves
	 * it stopped because UNIX is the FSBL.  Then tell the CPU the frequency
	 * via CNTFRQ so timer_reload (cntfrq/HZ) is right.  Without this there
	 * is no clock tick and hence no preemption or timeouts.
	 */
	RCC_APB5ENSETR = STGENCEN;		/* STGEN bus clock */
	(void)RCC_APB5ENSETR;			/* read-back before access */
	RCC_STGENCKSELR = (RCC_STGENCKSELR & ~3U) | STGENSRC_HSE;
	R32(STGENC + 0x00) = 0;			/* CNTCR: stop counter */
	R32(STGENC + 0x20) = HSE_HZ;		/* CNTFID0: frequency */
	R32(STGENC + 0x08) = 0;			/* CNTCVL: counter low = 0 */
	R32(STGENC + 0x0c) = 0;			/* CNTCVU: counter high = 0 */
	R32(STGENC + 0x00) = 1;			/* CNTCR.EN: start counter */
	cntfrq_set(HSE_HZ);

	/*
	 * PLL2 -> 533 MHz on its R output, which clocks the DDR PHY (DDR3-1066);
	 * ddr_init() needs this running first.  Coefficients are the board's
	 * (bootloader setup.c, HSE source, fractional): DIVM2=3 (/3), DIVN=66
	 * (x66), FRACV=0x1400, DIVP=DIVQ=2, DIVR=1 -> VCO 533 MHz, R = 533 MHz.
	 * We only ENABLE PLL2 and leave the AXI source on the ROM default: DDR
	 * takes PLL2_R directly, so there is no live bus-clock switch and a wrong
	 * value just fails ddr_init() with the console still alive.
	 * TODO(bench, #28): the AXI-on-PLL2 speedup (a live switch -- park AXI,
	 * reconfigure, switch back, as HAL_RCC_ClockConfig does) and PLL1 (MPU)
	 * remain; validate PLL2/PLL4 lock on the PCB.
	 */
	RCC_PLL2CR &= ~PLL2_PLLON;		/* disable before reconfigure */
	for (timo = 10000; timo > 0 && (RCC_PLL2CR & PLL2_RDY); timo--)
		;
	RCC_RCK12SELR = (RCC_RCK12SELR & ~7U) | PLL12SRC_HSE;
	RCC_PLL2CFGR1 = 0x00020041u;		/* DIVM2=2 (/3), DIVN=65 (x66) */
	RCC_PLL2CFGR2 = 0x00000101u;		/* DIVP=1 (/2), DIVQ=1 (/2), DIVR=0 (/1) */
	RCC_PLL2FRACR = 0x1400u << 3;		/* FRACV */
	RCC_PLL2FRACR |= PLL2_FRACLE;		/* latch fractional value */
	RCC_PLL2CR |= PLL2_DIVEN;		/* enable P/Q/R outputs */
	RCC_PLL2CR |= PLL2_PLLON;		/* enable PLL2 */
	for (timo = 100000; timo > 0 && !(RCC_PLL2CR & PLL2_RDY); timo--)
		;

	/*
	 * PLL4 -> P output 50 MHz (VCO = 24/2 x 50 = 600 MHz, /12), routed as the
	 * SDMMC1 card kernel clock so the SD block driver can read the rootfs.
	 * Integer mode (no FRACV).  Board coefficients (setup.c): DIVM4=2, DIVN=50,
	 * DIVP=12, DIVQ=25, DIVR=6.  Peripheral clock only -- no live bus switch.
	 */
	RCC_PLL4CR &= ~PLL2_PLLON;
	for (timo = 10000; timo > 0 && (RCC_PLL4CR & PLL2_RDY); timo--)
		;
	RCC_RCK4SELR = (RCC_RCK4SELR & ~7U) | PLL4SRC_HSE;
	RCC_PLL4CFGR1 = 0x00010031u;		/* DIVM4=1 (/2), DIVN=49 (x50) */
	RCC_PLL4CFGR2 = 0x00051811u;		/* DIVP=11 (/12), DIVQ=24 (/25), DIVR=5 (/6) */
	RCC_PLL4CR |= PLL2_DIVEN;		/* enable P/Q/R outputs */
	RCC_PLL4CR |= PLL2_PLLON;
	for (timo = 100000; timo > 0 && !(RCC_PLL4CR & PLL2_RDY); timo--)
		;
	RCC_SDMMC12CKSELR = (RCC_SDMMC12CKSELR & ~7U) | SDMMC1SRC_PLL4;
}

/*
 * DDR controller (DDRCTRL @ DDRCTRL, register offset:value) and PHY (DDRPHYC)
 * settings for the board's DDR3-1066 (1x4Gb, 533 MHz) part.  Values are the
 * DDR_* defines from the reference bootloader's board.h; offsets are the
 * DDRCTRL_TypeDef/DDRPHYC_TypeDef member offsets.  Terminated by off==0xFFFF.
 */
struct ddrreg { unsigned short off; unsigned int val; };

/* DDRCTRL static + timing + address-map groups (programmed before INIT0). */
static const struct ddrreg ddrctrl_main[] = {
	{ 0x000, 0x00040401u },	/* MSTR */
	{ 0x010, 0x00000010u },	/* MRCTRL0 */
	{ 0x014, 0x00000000u },	/* MRCTRL1 */
	{ 0x020, 0x00000000u },	/* DERATEEN */
	{ 0x024, 0x00800000u },	/* DERATEINT */
	{ 0x030, 0x00000000u },	/* PWRCTL */
	{ 0x034, 0x00400010u },	/* PWRTMG */
	{ 0x038, 0x00000000u },	/* HWLPCTL */
	{ 0x050, 0x00210000u },	/* RFSHCTL0 */
	{ 0x060, 0x00000000u },	/* RFSHCTL3 */
	{ 0x0C0, 0x00000000u },	/* CRCPARCTL0 */
	{ 0x180, 0xC2000040u },	/* ZQCTL0 */
	{ 0x190, 0x02060105u },	/* DFITMG0 */
	{ 0x194, 0x00000202u },	/* DFITMG1 */
	{ 0x198, 0x07000000u },	/* DFILPCFG0 */
	{ 0x1A0, 0xC0400003u },	/* DFIUPD0 */
	{ 0x1A4, 0x00000000u },	/* DFIUPD1 */
	{ 0x1A8, 0x00000000u },	/* DFIUPD2 */
	{ 0x1C4, 0x00000000u },	/* DFIPHYMSTR */
	{ 0x244, 0x00000001u },	/* ODTMAP */
	{ 0x300, 0x00000000u },	/* DBG0 */
	{ 0x304, 0x00000000u },	/* DBG1 */
	{ 0x30C, 0x00000000u },	/* DBGCMD */
	{ 0x36C, 0x00000000u },	/* POISONCFG */
	{ 0x400, 0x00000010u },	/* PCCFG */
	{ 0x064, 0x0081008Bu },	/* RFSHTMG */
	{ 0x100, 0x121B2414u },	/* DRAMTMG0 */
	{ 0x104, 0x000A041Cu },	/* DRAMTMG1 */
	{ 0x108, 0x0608090Fu },	/* DRAMTMG2 */
	{ 0x10C, 0x0050400Cu },	/* DRAMTMG3 */
	{ 0x110, 0x08040608u },	/* DRAMTMG4 */
	{ 0x114, 0x06060403u },	/* DRAMTMG5 */
	{ 0x118, 0x02020002u },	/* DRAMTMG6 */
	{ 0x11C, 0x00000202u },	/* DRAMTMG7 */
	{ 0x120, 0x00001005u },	/* DRAMTMG8 */
	{ 0x138, 0x000000A0u },	/* DRAMTMG14 */
	{ 0x240, 0x06000600u },	/* ODTCFG */
	{ 0x204, 0x00080808u },	/* ADDRMAP1 */
	{ 0x208, 0x00000000u },	/* ADDRMAP2 */
	{ 0x20C, 0x00000000u },	/* ADDRMAP3 */
	{ 0x210, 0x00001F1Fu },	/* ADDRMAP4 */
	{ 0x214, 0x07070707u },	/* ADDRMAP5 */
	{ 0x218, 0x0F070707u },	/* ADDRMAP6 */
	{ 0x224, 0x00000000u },	/* ADDRMAP9 */
	{ 0x228, 0x00000000u },	/* ADDRMAP10 */
	{ 0x22C, 0x00000000u },	/* ADDRMAP11 */
	{ 0xFFFF, 0 }
};

/* DDRCTRL performance/QoS group (programmed after INIT0.SKIP_DRAM_INIT). */
static const struct ddrreg ddrctrl_perf[] = {
	{ 0x250, 0x00000F01u },	/* SCHED */
	{ 0x254, 0x00000000u },	/* SCHED1 */
	{ 0x25C, 0x00000001u },	/* PERFHPR1 */
	{ 0x264, 0x04000200u },	/* PERFLPR1 */
	{ 0x26C, 0x08000400u },	/* PERFWR1 */
	{ 0x404, 0x00000000u },	/* PCFGR_0 */
	{ 0x408, 0x00000000u },	/* PCFGW_0 */
	{ 0x494, 0x00100009u },	/* PCFGQOS0_0 */
	{ 0x498, 0x00000020u },	/* PCFGQOS1_0 */
	{ 0x49C, 0x01100B03u },	/* PCFGWQOS0_0 */
	{ 0x4A0, 0x01000200u },	/* PCFGWQOS1_0 */
	{ 0xFFFF, 0 }
};

/* DDRPHYC register + timing groups (programmed after the PHY resets clear). */
static const struct ddrreg ddrphy_regs[] = {
	{ 0x008, 0x01442E02u },	/* PGCR */
	{ 0x024, 0x10400812u },	/* ACIOCR */
	{ 0x028, 0x00000C40u },	/* DXCCR */
	{ 0x02C, 0xF200011Fu },	/* DSGCR */
	{ 0x030, 0x0000000Bu },	/* DCR */
	{ 0x050, 0x00010000u },	/* ODTCR */
	{ 0x184, 0x00000038u },	/* ZQ0CR1 */
	{ 0x1C0, 0x0000CE81u },	/* DX0GCR */
	{ 0x200, 0x0000CE81u },	/* DX1GCR */
	{ 0x018, 0x0022AA5Bu },	/* PTR0 */
	{ 0x01C, 0x04841104u },	/* PTR1 */
	{ 0x020, 0x042DA068u },	/* PTR2 */
	{ 0x034, 0x38D488D0u },	/* DTPR0 */
	{ 0x038, 0x098B00D8u },	/* DTPR1 */
	{ 0x03C, 0x10023600u },	/* DTPR2 */
	{ 0x040, 0x00000840u },	/* MR0 */
	{ 0x044, 0x00000000u },	/* MR1 */
	{ 0x048, 0x00000208u },	/* MR2 */
	{ 0x04C, 0x00000000u },	/* MR3 */
	{ 0xFFFF, 0 }
};

#define DDRC(o)		R32(DDRCTRL + (o))
#define DPHY(o)		R32(DDRPHYC + (o))
#define RCC_DDRITFCR	R32(RCC + 0x5C0)
#define DDR_ALLRST	0x000FC000U	/* CAPB|AXI|CORE|DPHYAPB|DPHY|DPHYCTL rst */
#define DDR_CLKEN	0x00000251U	/* DDRC1|DDRPHYC|DDRPHYCAPB|DDRCAPB en */
#define DDR_PHYRST	0x000C0000U	/* DPHYRST|DPHYCTLRST */
#define DDR_CAPBRST	0x00004000U	/* DDRCAPBRST */
#define DDR_LATERST	0x00038000U	/* DDRCORERST|DDRCAXIRST|DPHYAPBRST */
#define DDR_AXIDCGEN	0x00000100U
#define DFIMISC_COMPLETE 0x00000001U	/* DDRCTRL DFIMISC.DFI_INIT_COMPLETE_EN */
#define DDR_PIR_INIT	0x0001007FU	/* DLLSRST|DLLLOCK|ZCAL|ITMSRST|DRAMINIT|DRAMRST|ICPC|INIT */
#define DDR_PIR_TRAIN	0x00000081U	/* QSTRN|INIT: DQS gate (data-eye) training */
#define RFSHCTL3_DISAUREF 0x00000001U	/* RFSHCTL3.dis_auto_refresh */

/*
 * DDR3-1066 bring-up (533 MHz, 512 MB), translated from the reference
 * bootloader's HAL_DDR_Init.  Unverifiable in QEMU (no DDR-controller model),
 * so it is a bench candidate -- the register values/offsets above are exact,
 * but the analog parts (PHY DLL lock, ZQ calibration, DQS training triggered
 * by PIR and polled on PGSR.IDONE) only converge against real silicon.
 * TODO(bench, #28): requires PLL2_R = 533 MHz from clock_init first.  Tune on
 * the PCB: if PGSR.IDONE or STAT.operating_mode never settles, add the SWCTL/
 * SWSTAT sw_done handshakes the HAL wraps around quasi-dynamic writes.
 */
void
ddr_init(void)
{
	const struct ddrreg *r;
	int timo;

	/* If the DDR I/O pads are in retention (PWR_CR3.DDRRETEN, e.g. left from a
	 * prior low-power state), the PHY cannot drive the DRAM and init/training
	 * fail.  Disable retention exactly as the bootloader does.  PWR_CR3 @ 0x5000100C. */
	if (R32(0x5000100C) & (1U << 12)) {
		R32(0x5000100C) |= (1U << 11);		/* DDRSRDIS = 1 */
		R32(0x5000100C) &= ~(1U << 12);		/* DDRRETEN = 0 */
	}

	/* Enable the MCE + TZC peripheral clocks before touching TZC, else the
	 * bus access to an unclocked peripheral stalls (as the bootloader does). */
	R32(RCC + 0x780) = 0x00000002U;		/* AHB6ENSETR: MCE clock (bit 1) */
	R32(RCC + 0x740) = 0x00000800U;		/* APB5ENSETR: TZC clock (bit 11) */
	(void)R32(RCC + 0x740);			/* read-back: clocks live */

	/* TZC: open DDR region 0 to all masters (non-secure) */
	R32(TZC + 0x008) = 0;			/* GATE_KEEPER off */
	R32(TZC + 0x114) = 0xFFFFFFFFU;		/* REG_ID_ACCESS0 */
	R32(TZC + 0x110) = 0xC0000001U;		/* REG_ATTRIBUTES0 */
	R32(TZC + 0x008) = 1;			/* GATE_KEEPER on */
	R32(BSEC + 0x000) = 0x47FU;		/* BSEC_DENABLE: unlock debug */

	/* 1. assert resets, enable DDR clocks, release PHY + APB resets */
	RCC_DDRITFCR &= ~DDR_AXIDCGEN;		/* no clock gating during init */
	RCC_DDRITFCR |= DDR_ALLRST;
	RCC_DDRITFCR |= DDR_CLKEN;
	RCC_DDRITFCR &= ~DDR_PHYRST;		/* deassert DPHY rstn + ctl_rstn */
	RCC_DDRITFCR &= ~DDR_CAPBRST;		/* deassert presetn */
	for (timo = 1000; timo > 0; timo--)	/* >=128 cycles for end logic */
		;

	/* 2. program the controller while the PHY is held off */
	DDRC(0x1B0) &= ~DFIMISC_COMPLETE;	/* stop uMCTL2 before PHY ready */
	for (r = ddrctrl_main; r->off != 0xFFFF; r++)
		DDRC(r->off) = r->val;
	DDRC(0x000) &= ~0x8000U;			/* DDR3: clear MSTR.DLL_OFF_MODE */
	DDRC(0x0D0) = 0x4002004EU;		/* INIT0: skip_dram_init=0b01 (PHY inits DRAM) + cke timings */
	for (r = ddrctrl_perf; r->off != 0xFFFF; r++)
		DDRC(r->off) = r->val;

	/* 3. release controller core/AXI and PHY APB resets */
	RCC_DDRITFCR &= ~DDR_LATERST;

	/* 4. program the PHY */
	for (r = ddrphy_regs; r->off != 0xFFFF; r++)
		DPHY(r->off) = r->val;
	DPHY(0x044) &= ~0x1U;			/* DDR3: clear MR1.DE */

	/* 4b. wait for the PHY's post-reset auto-init (PGSR.IDONE) BEFORE issuing
	 * the PIR.  The reference does ddrphy_idone_wait() here; writing PIR while
	 * the PHY is still auto-initializing corrupts the DRAM init. */
	for (timo = 1000000; timo > 0 && !(DPHY(0x00C) & 0x1U); timo--)
		;

	/* 5. run PHY init (DLL/ZQ/ITM/DRAM init) and wait for completion */
	DPHY(0x004) = DDR_PIR_INIT;		/* PIR */
	for (timo = 0; timo < 20; timo++)	/* >=10 cycles before PGSR read */
		;
	for (timo = 1000000; timo > 0 &&
	     !(DPHY(0x00C) & 0x1U) && !(DPHY(0x00C) & 0x3E0U); timo--)
		;				/* poll PGSR.IDONE or error (HAL waits on IDONE) */

	/* 6. signal DFI init complete (quasi-dynamic -> sw_done handshake), wait NORMAL.
	 * SWCTL.sw_done=0, change reg, sw_done=1, wait SWSTAT.sw_done_ack -- without
	 * this the controller ignores the change. */
	DDRC(0x320) &= ~0x1U;			/* SWCTL.sw_done = 0 */
	DDRC(0x1B0) |= DFIMISC_COMPLETE;
	DDRC(0x320) |= 0x1U;			/* SWCTL.sw_done = 1 */
	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
		;				/* wait SWSTAT.sw_done_ack */
	for (timo = 1000000; timo > 0 && (DDRC(0x004) & 0x7U) != 0x1U; timo--)
		;				/* poll STAT.operating_mode == NORMAL */

	/* 6b. DQS gate (data-eye) training -- without it the read data path is
	 * uncalibrated and DDR reads stall.  Disable auto-refresh + dfi_init_complete
	 * via the sw_done handshake (quasi-dynamic) so refresh does not corrupt the
	 * training, run PIR=QSTRN, poll PGSR, then restore the same way. */
	DDRC(0x320) &= ~0x1U;
	DDRC(0x1B0) &= ~DFIMISC_COMPLETE;	/* clear dfi_init_complete_en */
	DDRC(0x060) |= RFSHCTL3_DISAUREF;	/* RFSHCTL3: disable auto-refresh */
	DDRC(0x320) |= 0x1U;
	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
		;
	DPHY(0x004) = DDR_PIR_TRAIN;		/* PIR = QSTRN|INIT */
	for (timo = 0; timo < 10000; timo++)	/* ~10us: let PGSR.IDONE drop before polling */
		;
	for (timo = 1000000; timo > 0 &&
	     !(DPHY(0x00C) & 0x1U) && !(DPHY(0x00C) & 0x3E0U); timo--)
		;				/* poll PGSR.IDONE or error */
	DDRC(0x320) &= ~0x1U;
	DDRC(0x060) = 0x00000000u;		/* RFSHCTL3: restore (auto-refresh on) */
	DDRC(0x1B0) |= DFIMISC_COMPLETE;	/* restore dfi_init_complete_en */
	DDRC(0x320) |= 0x1U;
	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
		;

	/* 7. open the AXI port, restore clock gating */
	DDRC(0x490) |= 0x1U;			/* PCTRL_0.port_en */
	RCC_DDRITFCR |= DDR_AXIDCGEN;
}
