extern void _exit(int n);
extern void _cleanup(void);
void
exit(int n)
{
	_cleanup();
	_exit(n);
}
