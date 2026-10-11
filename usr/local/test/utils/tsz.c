#include <stdio.h>
#include <a.out.h>

struct nlist nl[] = {
	{ "_nbuf", 0, 0 },
	{ "_ninode", 0, 0 },
	{ "_nfile", 0, 0 },
	{ "_nmount", 0, 0 },
	{ "_ncall", 0, 0 },
	{ "_nproc", 0, 0 },
	{ "_ntext", 0, 0 },
	{ "_nclist", 0, 0 },
	{ "", 0, 0 },
};
int pid[1000];

int
main(int argc, char **argv)
{
	int k, i, n, v;

	if (argc > 1) {
		n = atoi(argv[1]);
		for (i = 0; i < n; i++) {
			if ((pid[i] = fork()) == 0) {
				pause();
				_exit(0);
			}
			if (pid[i] < 0)
				break;
		}
		printf("forked %d\n", i);
		if (argc > 2)
			system(argv[2]);
		while (--i >= 0)
			kill(pid[i], 9);
		while (wait(&v) != -1)
			;
		return 0;
	}
	nlist("/unix", nl);
	k = open("/dev/kmem", 0);
	for (i = 0; nl[i].n_name[0]; i++) {
		v = 0;
		if (nl[i].n_value != 0) {
			lseek(k, (long)nl[i].n_value, 0);
			read(k, (char *)&v, sizeof(v));
		}
		printf("%.7s %d\n", nl[i].n_name+1, v);
	}
	return 0;
}
