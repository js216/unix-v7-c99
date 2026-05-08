#include "../lib/u.h"

int
main(void)
{

	puts("init: multi-user\n");
	(void)exec("/etc/getty");
	puts("init: cannot exec getty\n");
	return(1);
}
