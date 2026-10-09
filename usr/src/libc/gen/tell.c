/*
 * return offset in file.
 */

long	lseek();

long tell(f)
int f;
{
	return(lseek(f, 0L, 1));
}
