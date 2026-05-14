/*
 * return offset in file.
 */

extern long lseek(int, long, int);

long tell(f)
int f;
{
	return(lseek(f, 0L, 1));
}
