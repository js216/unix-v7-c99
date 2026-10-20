#include <stdio.h>
#include <a.out.h>
#define SPACE 100		/* number of symbols read at a time */

int
nlist(char *name, struct nlist *list)
{
	register struct nlist *p;
	register unsigned *q;
	int f, m, i;
	long sa;
	unsigned n, buf[13], sh[10], space[4*SPACE], st, ss;
	char c[10], *strs;

	for(p = list; p->n_name[0]; p++) {
		p->n_type = 0;
		p->n_value = 0;
	}
	f = open(name, 0);
	if(f < 0)
		return(-1);
	read(f, (char *)buf, sizeof buf);
	if(buf[0] != 0x464c457f){
		close(f);
		return(-1);
	}
	n = st = ss = 0;
	for(i = buf[12]&0xffff; --i >= 0 && n == 0; ) {
		lseek(f, buf[8] + i*40, 0);
		read(f, (char *)sh, sizeof sh);
		if(sh[1] == 2) {
			sa = sh[4];
			n = sh[5];
			lseek(f, buf[8] + sh[6]*40, 0);
			read(f, (char *)sh, sizeof sh);
			st = sh[4];
			ss = sh[5];
		}
	}
	if(n == 0 || (strs = malloc(ss + 1)) == NULL) {
		close(f);
		return(n == 0 ? 0 : -1);
	}
	lseek(f, st, 0);
	strs[read(f, strs, ss) > 0 ? ss : 0] = 0;

	while(n){
		m = sizeof space;
		if(n < sizeof space)
			m = n;
		lseek(f, sa, 0);
		read(f, (char *)space, m);
		n -= m;
		sa += m;
		for(q = space; (m -= 16) >= 0; q += 4) {
			c[0] = '_';
			c[1] = 0;
			if(q[0] < ss)
				strncpy(c+1, strs + q[0], 8);
			c[9] = 0;
			for(p = list; p->n_name[0]; p++)
				if(strncmp(p->n_name, c, 8) == 0) {
					p->n_value = q[1];
					p->n_type = N_EXT|N_DATA;
				}
		}
	}
	free(strs);
	close(f);
	return(0);
}
