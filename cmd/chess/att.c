#include "old.h"

struct step {
	int mask;
	int offset;
};

static struct step knights[] = {
	{ u2r1, -15 },
	{ u1r2, -6 },
	{ d1r2, 10 },
	{ d2r1, 17 },
	{ d2l1, 15 },
	{ d1l2, 6 },
	{ u1l2, -10 },
	{ u2l1, -17 },
};

static int
knight_attack(int square, int piece)
{
	int i;

	for (i = 0; i < 8; i++)
		if ((dir[square] & knights[i].mask) == 0 &&
		    board[square + knights[i].offset] == piece)
			return 1;
	return 0;
}

static int
diag_attack(int square, int mask, int offset, int bishop, int queen, int king)
{
	int piece;

	if (dir[square] & mask)
		return 0;
	square += offset;
	piece = board[square];
	if (piece != 0)
		return piece == bishop || piece == queen || piece == king;
	while ((dir[square] & mask) == 0) {
		square += offset;
		piece = board[square];
		if (piece == 0)
			continue;
		return piece == bishop || piece == queen;
	}
	return 0;
}

static int
rank_attack(int square, int mask, int offset, int rook, int queen, int king)
{
	int piece;

	if (dir[square] & mask)
		return 0;
	square += offset;
	piece = board[square];
	if (piece != 0)
		return piece == rook || piece == queen || piece == king;
	while ((dir[square] & mask) == 0) {
		square += offset;
		piece = board[square];
		if (piece == 0)
			continue;
		return piece == rook || piece == queen;
	}
	return 0;
}

static int
piece_attack(int square, int sign)
{
	if (knight_attack(square, 2 * sign))
		return 1;
	if (diag_attack(square, uleft, -9, 3 * sign, 5 * sign, 6 * sign))
		return 1;
	if (diag_attack(square, uright, -7, 3 * sign, 5 * sign, 6 * sign))
		return 1;
	if (diag_attack(square, dleft, 7, 3 * sign, 5 * sign, 6 * sign))
		return 1;
	if (diag_attack(square, dright, 9, 3 * sign, 5 * sign, 6 * sign))
		return 1;
	if (rank_attack(square, up, -8, 4 * sign, 5 * sign, 6 * sign))
		return 1;
	if (rank_attack(square, left, -1, 4 * sign, 5 * sign, 6 * sign))
		return 1;
	if (rank_attack(square, right, 1, 4 * sign, 5 * sign, 6 * sign))
		return 1;
	if (rank_attack(square, down, 8, 4 * sign, 5 * sign, 6 * sign))
		return 1;
	return 0;
}

int
battack(int square)
{
	if (piece_attack(square, 1))
		return 0;
	if ((dir[square] & uleft) == 0 && board[square - 9] == 1)
		return 0;
	if ((dir[square] & uright) == 0 && board[square - 7] == 1)
		return 0;
	return 1;
}

int
wattack(int square)
{
	if (piece_attack(square, -1))
		return 0;
	if ((dir[square] & dleft) == 0 && board[square + 7] == -1)
		return 0;
	if ((dir[square] & dright) == 0 && board[square + 9] == -1)
		return 0;
	return 1;
}
