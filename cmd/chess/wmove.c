/*
 * Local translation of v7/usr/src/games/chess/wmove.s.
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
wmove(int m)
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
	case -6:
		wkpos = to;
		flag &= ~03;
		if (from == 60 && to == 62) {
			value--;
			board[61] = -4;
			board[63] = 0;
			type = 2;
			break;
		}
		if (from == 60 && to == 58) {
			value--;
			board[59] = -4;
			board[56] = 0;
			type = 3;
			break;
		}
		if (game == 0)
			value += 2;
		type = 0;
		break;

	case -5:
		if (game == 0)
			value++;
		break;

	case -4:
		if (from == 63)
			flag &= ~01;
		else if (from == 56)
			flag &= ~02;
		break;

	case -1:
		diff = from - to;
		if (diff < 0)
			diff = -diff;
		if (diff == 1) {
			board[to] = 0;
			board[to - 8] = -1;
			type = 4;
			break;
		}
		if (diff == 16) {
			eppos = from - 8;
			break;
		}
		if (to < 24) {
			value -= 25;
			if (to < 16) {
				value -= 50;
				if (to < 8) {
					value -= 625;
					board[to] = -5;
					type = 5;
				}
			}
		}
		break;

	case -3:
	case -2:
		break;
	}

	*amp++ = type;
}

void
wremove(void)
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
		wkpos = from;
		break;

	case 2:
		board[63] = -4;
		board[61] = 0;
		wkpos = 60;
		break;

	case 3:
		board[56] = -4;
		board[59] = 0;
		wkpos = 60;
		break;

	case 4:
		board[from] = -1;
		board[to - 8] = 0;
		break;

	case 5:
		board[from] = -1;
		break;
	}
}
