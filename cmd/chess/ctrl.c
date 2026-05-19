#include "old.h"

#define	NONE	12345

static void
look(int square, int piece, int **out)
{
	if (board[square] == piece)
		*(*out)++ = piece;
}

static void
patt(int square, int mask, int offset, int **out)
{
	if (dir[square] & mask)
		return;
	square += offset;
	look(square, 2, out);
	look(square, -2, out);
}

static void
satt(int square, int mask, int offset, int pawn, int p1, int p2, int p3,
    int p4, int **out)
{
	int *oldout;

	if (dir[square] & mask)
		return;
	look(square + offset, pawn, out);
	for (;;) {
		if (dir[square] & mask)
			break;
		square += offset;
		if (board[square] == 0)
			continue;
		oldout = *out;
		look(square, p1, out);
		look(square, p2, out);
		look(square, p3, out);
		look(square, p4, out);
		if (*out != oldout)
			continue;
		break;
	}
}

void
attack(int square)
{
	int *out;

	out = attacv;
	patt(square, u2r1, -15, &out);
	patt(square, u1r2, -6, &out);
	patt(square, d2r1, 17, &out);
	patt(square, d2l1, 15, &out);
	patt(square, d1l2, 6, &out);
	patt(square, u1l2, -10, &out);
	patt(square, u2l1, -17, &out);

	satt(square, uleft, -9, 1, 3, -3, 5, -5, &out);
	satt(square, uright, -7, 1, 3, -3, 5, -5, &out);
	satt(square, dleft, 7, -1, 3, -3, 5, -5, &out);
	satt(square, dright, 9, -1, 3, -3, 5, -5, &out);
	satt(square, up, -8, NONE, 4, -4, 5, -5, &out);
	satt(square, left, -1, NONE, 4, -4, 5, -5, &out);
	satt(square, right, 1, NONE, 4, -4, 5, -5, &out);
	satt(square, down, 8, NONE, 4, -4, 5, -5, &out);
	*out++ = 0;
}
