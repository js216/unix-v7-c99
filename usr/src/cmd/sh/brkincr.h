/* PORT: bumped from v7's 01000/04000 (512/2048 bytes).  The original
 * values capped glob expansion at ~30 matches on stack-allocated
 * addg() output before sh's working stack ran out.  64KB is trivial
 * on 128 MiB qemu. */
#define BRKINCR 010000
#define BRKMAX 0200000
