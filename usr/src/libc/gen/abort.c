extern void _exit(int n);
void
abort(void)
{
	_exit(1);
}
