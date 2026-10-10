struct map
{
	int	m_size;
	int	m_addr;
};

extern struct map coremap[CMAPSIZ];	/* space for core allocation */
extern struct map swapmap[SMAPSIZ];	/* space for swap allocation */
extern struct map ptmap[PMAPSIZ];	/* space for page table allocation */
