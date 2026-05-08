#include "../lib/u.h"

int
main(void)
{

	puts("\nlogin: ");
	(void)exec("/bin/login");
	puts("getty: cannot exec login\n");
	return(1);
}
