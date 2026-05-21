/* Backing storage for V7 globals referenced by linked sys TUs.
 * struct user/buf/inode and rootdev/nblkdev live in arch/v7stubs.c.
 * cdevsw is all-zero (nodev); the v7 conf/c.c device table is PDP-11-
 * specific and is intentionally absent on the ARM port. */
#include "../h/param.h"
#include "../h/file.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/conf.h"
struct proc proc[NPROC];
struct file file[NFILE];
struct text text[NTEXT];
struct cdevsw cdevsw[1];	/* trailing zero row terminates */
