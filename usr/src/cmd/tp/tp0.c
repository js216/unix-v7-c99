#include "tp.h"
#include <tp_defs.h>
struct	tent	tpentry[TPB];
struct	dent	dir[MDIRENT], *edir, *lastd;
char	map[MAPSIZE], name[NAMELEN], name1[NAMELEN], *tname, **parg;
char	*nameblk, *top, *nptr;
int	narg, rnarg, wseeka, rseeka, tapsiz, fio;
short	ndirent, ndentb;
void	(*command)(void);
