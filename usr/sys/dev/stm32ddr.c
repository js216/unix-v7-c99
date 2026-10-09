/*
 *   STM32MP135 clock and DDR bring-up
 */
#include "../h/param.h"
#include "../h/seg.h"

void ddrclk(void);
void ddr_init(void);

#define RCC		0x50000000U
#define PWR		0x50001000U
#define DDRCTRL		0x5A003000U
#define DDRPHYC		0x5A004000U
#define BSEC		0x5C005000U
#define TZC		0x5C006000U
#define R32(a)		(*(volatile unsigned int *)(a))

#define RCC_OCENSETR	R32(RCC + 0x420)	/* oscillator enable (set-reg) */
#define RCC_OCRDYR	R32(RCC + 0x428)	/* oscillator ready */
#define HSEON		0x00000100U		/* OCENSETR/OCRDYR bit 8 */
#define HSERDY		0x00000100U
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

void
ddrinit(void)
{
	ddrclk();
	ddr_init();
}

void
ddrclk(void)
{
	int timo;

	RCC_OCENSETR = HSEON;
	for (timo = 100000; timo > 0 && !(RCC_OCRDYR & HSERDY); timo--)
		;

	RCC_PLL2CR &= ~PLL2_PLLON;
	for (timo = 10000; timo > 0 && (RCC_PLL2CR & PLL2_RDY); timo--)
		;
	RCC_RCK12SELR = (RCC_RCK12SELR & ~7U) | PLL12SRC_HSE;
	RCC_PLL2CFGR1 = 0x00020041u;		/* DIVM2=2 (/3), DIVN=65 (x66) */
	RCC_PLL2CFGR2 = 0x00000101u;		/* DIVP=1 (/2), DIVQ=1 (/2), DIVR=0 (/1) */
	RCC_PLL2FRACR = 0x1400u << 3;		/* FRACV */
	RCC_PLL2FRACR |= PLL2_FRACLE;
	RCC_PLL2CR |= PLL2_DIVEN;
	RCC_PLL2CR |= PLL2_PLLON;
	for (timo = 100000; timo > 0 && !(RCC_PLL2CR & PLL2_RDY); timo--)
		;
}

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

void
ddr_init(void)
{
	const struct ddrreg *r;
	int timo;

	if (R32(0x5000100C) & (1U << 12)) {
		R32(0x5000100C) |= (1U << 11);		/* DDRSRDIS = 1 */
		R32(0x5000100C) &= ~(1U << 12);		/* DDRRETEN = 0 */
	}

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

	/* 4b. wait for the PHY's post-reset auto-init (PGSR.IDONE) */
	for (timo = 1000000; timo > 0 && !(DPHY(0x00C) & 0x1U); timo--)
		;

	/* 5. run PHY init (DLL/ZQ/ITM/DRAM init) and wait for completion */
	DPHY(0x004) = DDR_PIR_INIT;		/* PIR */
	for (timo = 0; timo < 20; timo++)	/* >=10 cycles before PGSR read */
		;
	for (timo = 1000000; timo > 0 &&
	     !(DPHY(0x00C) & 0x1U) && !(DPHY(0x00C) & 0x3E0U); timo--)
		;				/* poll PGSR.IDONE or error (HAL waits on IDONE) */

	/* 6. signal DFI init complete via the sw_done handshake, wait NORMAL */
	DDRC(0x320) &= ~0x1U;			/* SWCTL.sw_done = 0 */
	DDRC(0x1B0) |= DFIMISC_COMPLETE;
	DDRC(0x320) |= 0x1U;			/* SWCTL.sw_done = 1 */
	for (timo = 100000; timo > 0 && !(DDRC(0x324) & 0x1U); timo--)
		;				/* wait SWSTAT.sw_done_ack */
	for (timo = 1000000; timo > 0 && (DDRC(0x004) & 0x7U) != 0x1U; timo--)
		;				/* poll STAT.operating_mode == NORMAL */

	/* 6b. DQS gate training, with auto-refresh off */
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
