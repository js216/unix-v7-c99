static	long	randx = 1;

void
srand(x)
unsigned x;
{
	randx = x;
}

int
rand()
{
	return(((randx = randx*1103515245 + 12345)>>16) & 077777);
}
