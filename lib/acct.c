/* Stub for the v7 acct(2) syscall — the C99/Armv7 kernel does not
 * service syscall #51 (sysacct), so this is a no-op so accton(8)
 * links. cmd/quot.c declares its own local int acct(struct dinode *)
 * which would clash if the stub were kept in compat.o; keeping it in
 * its own object lets libc.a pull it in only on demand (i.e. for
 * accton, not for quot).
 */
int
acct(file)
char *file;
{

	(void)file;
	return(0);
}
