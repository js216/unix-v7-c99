/*
 * Local translation of v7/usr/src/games/chess/bgen.s.
 */

#include "old.h"

struct gen_step {
	int mask;
	int offset;
};

static struct gen_step knight_steps[] = {
	{ u2r1, -15 },
	{ u1r2, -6 },
	{ d1r2, 10 },
	{ d2r1, 17 },
	{ d2l1, 15 },
	{ d1l2, 6 },
	{ u1l2, -10 },
	{ u2l1, -17 },
};

static struct gen_step bishop_steps[] = {
	{ uleft, -9 },
	{ uright, -7 },
	{ dleft, 7 },
	{ dright, 9 },
};

static struct gen_step rook_steps[] = {
	{ up, -8 },
	{ down, 8 },
	{ left, -1 },
	{ right, 1 },
};

static struct gen_step queen_king_steps[] = {
	{ uleft, -9 },
	{ uright, -7 },
	{ dleft, 7 },
	{ dright, 9 },
	{ up, -8 },
	{ left, -1 },
	{ right, 1 },
	{ down, 8 },
};

static void
bappend(int from, int to)
{

	*lmp++ = (pval + 6)[board[to]] - value;
	*lmp++ = (from << 8) | to;
}

static void
btry_local(int from, int mask, int offset)
{
	int to;

	if (dir[from] & mask)
		return;
	to = from + offset;
	if (board[to] > 0)
		return;
	bappend(from, to);
}

static void
bslide(int from, int mask, int offset)
{
	int to, piece;

	to = from;
	while ((dir[to] & mask) == 0) {
		to += offset;
		piece = board[to];
		if (piece > 0)
			return;
		if (piece == 0) {
			*lmp++ = -value;
			*lmp++ = (from << 8) | to;
			continue;
		}
		bappend(from, to);
		return;
	}
}

static void
bsliders(int from, struct gen_step *steps, int nsteps)
{
	int i;

	for (i = 0; i < nsteps; i++)
		bslide(from, steps[i].mask, steps[i].offset);
}

static void
bsteps(int from, struct gen_step *steps, int nsteps)
{
	int i;

	for (i = 0; i < nsteps; i++)
		btry_local(from, steps[i].mask, steps[i].offset);
}

static void
bpawn(int from)
{

	if ((dir[from] & dleft) == 0) {
		if (board[from + 7] < 0)
			btry_local(from, 0, 7);
		if (from + 7 == eppos)
			btry_local(from, 0, -1);
	}
	if ((dir[from] & dright) == 0) {
		if (board[from + 9] < 0)
			btry_local(from, 0, 9);
		if (from + 9 == eppos)
			btry_local(from, 0, 1);
	}
	if (board[from + 8] != 0)
		return;
	btry_local(from, 0, 8);
	if ((dir[from] & rank7) == 0)
		return;
	if (board[from + 16] != 0)
		return;
	btry_local(from, 0, 16);
}

void
bgen(void)
{
	int square, piece;

	for (square = 63; square >= 0; square--) {
		piece = board[square];
		if (piece <= 0)
			continue;
		switch (piece) {
		case 1:
			bpawn(square);
			break;
		case 2:
			bsteps(square, knight_steps, 8);
			break;
		case 3:
			bsliders(square, bishop_steps, 4);
			break;
		case 4:
			bsliders(square, rook_steps, 4);
			break;
		case 5:
			bsliders(square, queen_king_steps, 8);
			break;
		case 6:
			bsteps(square, queen_king_steps, 8);
			break;
		}
	}
}
