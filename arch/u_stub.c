/* Backing storage for V7 globals referenced by linked sys/*.c TUs.
 * struct user/buf/inode and rootdev/nblkdev live in arch/v7stubs.c.
 * cdevsw is all-zero (nodev) -- conf/c.c not yet linked. */
#include "../h/param.h"
#include "../h/file.h"
#include "../h/proc.h"
#include "../h/text.h"
#include "../h/callo.h"
#include "../h/conf.h"
#include "../h/tty.h"
struct proc proc[NPROC];
struct file file[NFILE];
struct text text[NTEXT];
struct cdevsw cdevsw[1];	/* trailing zero row terminates */
