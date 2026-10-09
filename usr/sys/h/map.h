struct map
{
	int	m_size;
	int	m_addr;
};

struct map coremap[CMAPSIZ];	/* space for core allocation */
struct map swapmap[SMAPSIZ];	/* space for swap allocation */
