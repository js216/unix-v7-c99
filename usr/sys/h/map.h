struct map
{
	int		m_size;		/* Armv7: 32-bit (clicks exceed 16 bits) */
	unsigned int	m_addr;
};

struct map coremap[CMAPSIZ];	/* space for core allocation */
struct map swapmap[SMAPSIZ];	/* space for swap allocation */
