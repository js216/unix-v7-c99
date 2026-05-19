#include <stdio.h>

#include "old.h"

#define	MOVE(f, t)	(((f) << 8) | (t))
#define	NEL(a)		((int)(sizeof(a) / sizeof((a)[0])))

static int failures;

static void
checki(const char *name, int got, int want)
{

	if (got == want)
		return;
	printf("%s: got %d want %d\n", name, got, want);
	failures++;
}

static void
clear_board(void)
{
	int i;

	for (i = 0; i < 64; i++)
		board[i] = 0;
}

static void
init_dirs(void)
{
	static int e[] = { 040, 020, 010, 0, 0, 1, 2, 4 };
	int i;

	for (i = 0; i < 8; i++)
		edge[i] = e[i];
	for (i = 0; i < 64; i++)
		dir[i] = (edge[i / 8] << 6) | edge[i % 8];
}

static void
reset_state(void)
{
	int i;

	clear_board();
	for (i = -6; i <= 6; i++)
		(pval + 6)[i] = i * 100;
	value = 1000;
	eppos = 64;
	lmp = lmbuf;
}

static void
check_vec(const char *name, const int *want, int nwant)
{
	int i, got;
	char tag[80];

	got = lmp - lmbuf;
	snprintf(tag, sizeof(tag), "%s count", name);
	checki(tag, got, nwant);
	for (i = 0; i < got && i < nwant; i++) {
		snprintf(tag, sizeof(tag), "%s[%d]", name, i);
		checki(tag, lmbuf[i], want[i]);
	}
}

static void
initial_position_counts(void)
{
	reset_state();
	board[0] = 4;
	board[1] = 2;
	board[2] = 3;
	board[3] = 5;
	board[4] = 6;
	board[5] = 3;
	board[6] = 2;
	board[7] = 4;
	board[8] = 1;
	board[9] = 1;
	board[10] = 1;
	board[11] = 1;
	board[12] = 1;
	board[13] = 1;
	board[14] = 1;
	board[15] = 1;
	board[48] = -1;
	board[49] = -1;
	board[50] = -1;
	board[51] = -1;
	board[52] = -1;
	board[53] = -1;
	board[54] = -1;
	board[55] = -1;
	board[56] = -4;
	board[57] = -2;
	board[58] = -3;
	board[59] = -5;
	board[60] = -6;
	board[61] = -3;
	board[62] = -2;
	board[63] = -4;
	wgen();
	checki("initial white count", (lmp - lmbuf) / 2, 20);

	reset_state();
	board[0] = 4;
	board[1] = 2;
	board[2] = 3;
	board[3] = 5;
	board[4] = 6;
	board[5] = 3;
	board[6] = 2;
	board[7] = 4;
	board[8] = 1;
	board[9] = 1;
	board[10] = 1;
	board[11] = 1;
	board[12] = 1;
	board[13] = 1;
	board[14] = 1;
	board[15] = 1;
	board[48] = -1;
	board[49] = -1;
	board[50] = -1;
	board[51] = -1;
	board[52] = -1;
	board[53] = -1;
	board[54] = -1;
	board[55] = -1;
	board[56] = -4;
	board[57] = -2;
	board[58] = -3;
	board[59] = -5;
	board[60] = -6;
	board[61] = -3;
	board[62] = -2;
	board[63] = -4;
	bgen();
	checki("initial black count", (lmp - lmbuf) / 2, 20);
}

static void
scan_order(void)
{
	static int wwant[] = {
		1000, MOVE(40, 25),
		1000, MOVE(40, 34),
		1000, MOVE(40, 50),
		1000, MOVE(40, 57),
		1000, MOVE(12, 4),
	};
	static int bwant[] = {
		-1000, MOVE(23, 38),
		-1000, MOVE(23, 29),
		-1000, MOVE(23, 13),
		-1000, MOVE(23, 6),
		-1000, MOVE(8, 16),
		-1000, MOVE(8, 24),
	};

	reset_state();
	board[40] = -2;
	board[12] = -1;
	wgen();
	check_vec("white scan order", wwant, NEL(wwant));

	reset_state();
	board[23] = 2;
	board[8] = 1;
	bgen();
	check_vec("black scan order", bwant, NEL(bwant));
}

static void
knight_edges(void)
{
	static int wwant[] = {
		1000, MOVE(7, 22),
		1000, MOVE(7, 13),
	};
	static int bwant[] = {
		-1000, MOVE(56, 41),
		-1000, MOVE(56, 50),
	};

	reset_state();
	board[7] = -2;
	wgen();
	check_vec("white knight edge", wwant, NEL(wwant));

	reset_state();
	board[56] = 2;
	bgen();
	check_vec("black knight edge", bwant, NEL(bwant));
}

static void
slider_behavior(void)
{
	static int wwant[] = {
		1000, MOVE(27, 19),
		900, MOVE(27, 11),
		1000, MOVE(27, 35),
		900, MOVE(27, 43),
		1000, MOVE(27, 26),
		700, MOVE(27, 25),
		500, MOVE(27, 28),
	};
	static int bwant[] = {
		-1000, MOVE(36, 27),
		-1200, MOVE(36, 18),
		-1000, MOVE(36, 29),
		-1000, MOVE(36, 22),
		-1000, MOVE(36, 15),
		-1100, MOVE(36, 43),
		-1100, MOVE(36, 45),
	};

	reset_state();
	board[27] = -4;
	board[11] = 1;
	board[25] = 3;
	board[28] = 5;
	board[43] = 1;
	wgen();
	check_vec("white slider", wwant, NEL(wwant));

	reset_state();
	board[36] = 3;
	board[18] = -2;
	board[45] = -1;
	board[43] = -1;
	bgen();
	check_vec("black slider", bwant, NEL(bwant));
}

static void
pawn_behavior(void)
{
	static int wwant[] = {
		900, MOVE(52, 43),
		900, MOVE(52, 45),
		1000, MOVE(52, 44),
		1000, MOVE(52, 36),
	};
	static int bwant[] = {
		-1100, MOVE(11, 18),
		-1100, MOVE(11, 20),
		-1000, MOVE(11, 19),
		-1000, MOVE(11, 27),
	};

	reset_state();
	board[52] = -1;
	board[43] = 1;
	board[45] = 1;
	wgen();
	check_vec("white pawn", wwant, NEL(wwant));

	reset_state();
	board[11] = 1;
	board[18] = -1;
	board[20] = -1;
	bgen();
	check_vec("black pawn", bwant, NEL(bwant));
}

static void
en_passant_behavior(void)
{
	static int wwant[] = {
		900, MOVE(36, 35),
	};
	static int bwant[] = {
		-1100, MOVE(27, 28),
	};

	reset_state();
	board[36] = -1;
	board[35] = 1;
	board[28] = 1;
	eppos = 27;
	wgen();
	check_vec("white en passant encoded", wwant, NEL(wwant));

	reset_state();
	board[27] = 1;
	board[28] = -1;
	board[35] = -1;
	eppos = 36;
	bgen();
	check_vec("black en passant encoded", bwant, NEL(bwant));
}

static void
score_formulas(void)
{
	static int wwant[] = {
		555, MOVE(36, 27),
	};
	static int bwant[] = {
		-957, MOVE(27, 36),
	};

	reset_state();
	value = 777;
	(pval + 6)[3] = 222;
	board[36] = -1;
	board[27] = 3;
	board[28] = 3;
	wgen();
	check_vec("white score formula", wwant, NEL(wwant));

	reset_state();
	value = 777;
	(pval + 6)[-4] = -180;
	board[27] = 1;
	board[36] = -4;
	board[35] = -1;
	bgen();
	check_vec("black score formula", bwant, NEL(bwant));
}

static void
lmp_appending(void)
{
	static int want[] = {
		1111, 2222,
		1000, MOVE(48, 40),
		1000, MOVE(48, 32),
	};

	reset_state();
	lmbuf[0] = 1111;
	lmbuf[1] = 2222;
	lmp = lmbuf + 2;
	board[48] = -1;
	wgen();
	check_vec("lmp append", want, NEL(want));
}

int
main(void)
{

	init_dirs();
	initial_position_counts();
	scan_order();
	knight_edges();
	slider_behavior();
	pawn_behavior();
	en_passant_behavior();
	score_formulas();
	lmp_appending();
	if (failures) {
		printf("gen_check: %d failure(s)\n", failures);
		return 1;
	}
	printf("gen_check: ok\n");
	return 0;
}
