/* v7-style kernel message-buffer ring.  msgbuf[] is declared in
 * h/systm.h as a tentative definition (no =initializer); the actual
 * BSS allocation lands here.  msgbufp tracks the next write position;
 * the v7 KL11 console driver (dev/kl.c) ships its own copy of this
 * pair but kl.c isn't linked into the ARM kernel build, so the same
 * symbols live here.  /etc/dmesg locates them via nlist("/unix", ...)
 * and reads through /dev/mem.
 */

#include "../h/param.h"

char	msgbuf[MSGBUFS];
char	*msgbufp = msgbuf;
