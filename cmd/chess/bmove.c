/*
 * Local translation of v7/usr/src/games/chess/bmove.s.
 */

#include "old.h"

static int
sqfrom(int m)
{

	return (m >> 8) & 0377;
}

static int
sqto(int m)
{

	return m & 0377;
}

void
bmove(int m)
{
	int from, to, captured, piece, diff, type;

	from = sqfrom(m);
	to = sqto(m);
	captured = board[to];
	type = 1;

	*amp++ = value;
	*amp++ = flag;
	*amp++ = eppos;
	*amp++ = from;
	*amp++ = to;
	*amp++ = captured;

	if (captured)
		value -= (pval + 6)[captured];

	piece = board[from];
	board[to] = piece;
	board[from] = 0;
	eppos = -1;

	switch (piece) {
	case 1:
		diff = from - to;
		if (diff < 0)
			diff = -diff;
		if (diff == 1) {
			board[to] = 0;
			board[to + 8] = 1;
			type = 4;
			break;
		}
		if (diff == 16) {
			eppos = from + 8;
			break;
		}
		if (to >= 40) {
			value += 25;
			if (to >= 48) {
				value += 50;
				if (to >= 56) {
					value += 625;
					board[to] = 5;
					type = 5;
				}
			}
		}
		break;

	case 4:
		if (from == 7)
			flag &= ~010;
		else if (from == 0)
			flag &= ~020;
		break;

	case 5:
		if (game == 0)
			value--;
		break;

	case 6:
		bkpos = to;
		flag &= ~030;
		if (from == 4 && to == 6) {
			value++;
			board[5] = 4;
			board[7] = 0;
			type = 2;
			break;
		}
		if (from == 4 && to == 2) {
			value++;
			board[3] = 4;
			board[0] = 0;
			type = 3;
			break;
		}
		if (game == 0)
			value -= 2;
		type = 0;
		break;

	case 2:
	case 3:
		break;
	}

	*amp++ = type;
}

void
bremove(void)
{
	int type, captured, to, from;

	type = *--amp;
	captured = *--amp;
	to = *--amp;
	from = *--amp;
	eppos = *--amp;
	flag = *--amp;
	value = *--amp;

	board[from] = board[to];
	board[to] = captured;

	switch (type) {
	case 0:
		bkpos = from;
		break;

	case 2:
		board[7] = 4;
		board[5] = 0;
		bkpos = 4;
		break;

	case 3:
		board[0] = 4;
		board[3] = 0;
		bkpos = 4;
		break;

	case 4:
		board[from] = 1;
		board[to + 8] = 0;
		break;

	case 5:
		board[from] = 1;
		break;
	}
}
