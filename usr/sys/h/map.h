struct map
{
	int	m_size;
	int	m_addr;
};

extern struct map swapmap[];	/* space for swap allocation */
extern struct map ptmap[];	/* space for page table allocation */
