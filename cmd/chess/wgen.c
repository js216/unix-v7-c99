/*
 * Local translation of v7/usr/src/games/chess/wgen.s.
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
wappend(int from, int to)
{

	*lmp++ = value - (pval + 6)[board[to]];
	*lmp++ = (from << 8) | to;
}

static void
wtry_local(int from, int mask, int offset)
{
	int to;

	if (dir[from] & mask)
		return;
	to = from + offset;
	if (board[to] < 0)
		return;
	wappend(from, to);
}

static void
wslide(int from, int mask, int offset)
{
	int to, piece;

	to = from;
	while ((dir[to] & mask) == 0) {
		to += offset;
		piece = board[to];
		if (piece < 0)
			return;
		if (piece == 0) {
			*lmp++ = value;
			*lmp++ = (from << 8) | to;
			continue;
		}
		wappend(from, to);
		return;
	}
}

static void
wsliders(int from, struct gen_step *steps, int nsteps)
{
	int i;

	for (i = 0; i < nsteps; i++)
		wslide(from, steps[i].mask, steps[i].offset);
}

static void
wsteps(int from, struct gen_step *steps, int nsteps)
{
	int i;

	for (i = 0; i < nsteps; i++)
		wtry_local(from, steps[i].mask, steps[i].offset);
}

static void
wpawn(int from)
{

	if ((dir[from] & uleft) == 0) {
		if (board[from - 9] > 0)
			wtry_local(from, 0, -9);
		if (from - 9 == eppos)
			wtry_local(from, 0, -1);
	}
	if ((dir[from] & uright) == 0) {
		if (board[from - 7] > 0)
			wtry_local(from, 0, -7);
		if (from - 7 == eppos)
			wtry_local(from, 0, 1);
	}
	if (board[from - 8] != 0)
		return;
	wtry_local(from, 0, -8);
	if ((dir[from] & rank2) == 0)
		return;
	if (board[from - 16] != 0)
		return;
	wtry_local(from, 0, -16);
}

void
wgen(void)
{
	int square, piece;

	for (square = 63; square >= 0; square--) {
		piece = board[square];
		if (piece >= 0)
			continue;
		switch (piece) {
		case -6:
			wsteps(square, queen_king_steps, 8);
			break;
		case -5:
			wsliders(square, queen_king_steps, 8);
			break;
		case -4:
			wsliders(square, rook_steps, 4);
			break;
		case -3:
			wsliders(square, bishop_steps, 4);
			break;
		case -2:
			wsteps(square, knight_steps, 8);
			break;
		case -1:
			wpawn(square);
			break;
		}
	}
}
