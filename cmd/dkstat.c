/*
 * dkstat -- print the kernel's per-drive transfer counters and the
 * dev/bio.c io_info aggregate.  The v7-original tool is iostat(8),
 * which leans on printf("%f", ...) and on dk_time[32]; this port has
 * no floating-point printf and no clock tick to bump dk_time, so this
 * is a minimal integer-only stand-in that surfaces what the kernel
 * does maintain: dk_busy, dk_numb[], dk_wds[], and io_info.nread /
 * .nwrite / .nreada / .ncache.  Symbol lookup uses the same
 * nlist+/dev/mem path as /etc/dmesg.
 */

#include <stdio.h>
#include <a.out.h>

struct iostat_info {
	int	nbuf;
	long	nread;
	long	nreada;
	long	ncache;
	long	nwrite;
	long	bufcount[50];
};

struct nlist nl[] = {
	{"_dk_busy",            0, 0},
	{"_dk_numb",            0, 0},
	{"_dk_wds",             0, 0},
	{"_io_info",            0, 0},
	{"_dk_time",            0, 0},
	{"_lbolt",              0, 0},
	{"\0\0\0\0\0\0\0\0",    0, 0}
};

int
main(int argc, char **argv)
{
	int mem;
	int dk_busy;
	long dk_numb[3];
	long dk_wds[3];
	struct iostat_info io_info;
	long dk_time[32];
	int lbolt;
	int i;
	long dk_time_sum;

	(void)argc; (void)argv;
	nlist("/unix", nl);
	if (nl[0].n_type == 0) {
		printf("dkstat: no kernel namelist in /unix\n");
		exit(1);
	}
	if ((mem = open("/dev/kmem", 0)) < 0) {
		printf("dkstat: no /dev/kmem\n");
		exit(1);
	}
	lseek(mem, (long)nl[0].n_value, 0);
	read(mem, (char *)&dk_busy, sizeof(dk_busy));
	lseek(mem, (long)nl[1].n_value, 0);
	read(mem, (char *)dk_numb, sizeof(dk_numb));
	lseek(mem, (long)nl[2].n_value, 0);
	read(mem, (char *)dk_wds, sizeof(dk_wds));
	lseek(mem, (long)nl[3].n_value, 0);
	read(mem, (char *)&io_info, sizeof(io_info));
	if (nl[4].n_type != 0) {
		lseek(mem, (long)nl[4].n_value, 0);
		read(mem, (char *)dk_time, sizeof(dk_time));
	} else {
		for (i = 0; i < 32; i++) dk_time[i] = 0;
	}
	if (nl[5].n_type != 0) {
		lseek(mem, (long)nl[5].n_value, 0);
		read(mem, (char *)&lbolt, sizeof(lbolt));
	} else {
		lbolt = -1;
	}
	close(mem);
	printf("dk_busy 0x%x\n", dk_busy);
	printf("drive    numb        wds\n");
	printf("0     %6ld %10ld\n", dk_numb[0], dk_wds[0]);
	printf("1     %6ld %10ld\n", dk_numb[1], dk_wds[1]);
	printf("2     %6ld %10ld\n", dk_numb[2], dk_wds[2]);
	printf("io_info  nread=%ld nreada=%ld ncache=%ld nwrite=%ld nbuf=%d\n",
	    io_info.nread, io_info.nreada, io_info.ncache, io_info.nwrite,
	    io_info.nbuf);
	dk_time_sum = 0;
	for (i = 0; i < 32; i++) dk_time_sum += dk_time[i];
	printf("lbolt %d  dk_time_sum %ld  dk_time[0..3]= %ld %ld %ld %ld\n",
	    lbolt, dk_time_sum,
	    dk_time[0], dk_time[1], dk_time[2], dk_time[3]);
	exit(0);
}
