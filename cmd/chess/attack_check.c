#include <stdio.h>

#include "old.h"

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
check_vec(const char *name, const int *want)
{
	int i;
	char tag[80];

	for (i = 0; ; i++) {
		snprintf(tag, sizeof(tag), "%s[%d]", name, i);
		checki(tag, attacv[i], want[i]);
		if (want[i] == 0)
			break;
	}
}

static void
test_pawns(void)
{
	clear_board();
	checki("black no attack", battack(27), 1);
	checki("white no attack", wattack(27), 1);
	board[18] = 1;
	checki("black pawn uleft", battack(27), 0);
	clear_board();
	board[20] = 1;
	checki("black pawn uright", battack(27), 0);
	clear_board();
	board[34] = -1;
	checki("white pawn dleft", wattack(27), 0);
	clear_board();
	board[36] = -1;
	checki("white pawn dright", wattack(27), 0);
}

static void
test_knights(void)
{
	static int offsets[] = { -15, -6, 10, 17, 15, 6, -10, -17 };
	int i;

	for (i = 0; i < 8; i++) {
		clear_board();
		board[27 + offsets[i]] = 2;
		checki("black knight direction", battack(27), 0);
		clear_board();
		board[27 + offsets[i]] = -2;
		checki("white knight direction", wattack(27), 0);
	}
	clear_board();
	board[17] = 2;
	checki("black knight right edge masked", battack(7), 1);
	clear_board();
	board[6] = -2;
	checki("white knight left edge masked", wattack(0), 1);
}

static void
test_rays_and_kings(void)
{
	clear_board();
	board[3] = 4;
	checki("black rook ray", battack(27), 0);
	clear_board();
	board[0] = -3;
	checki("white bishop ray", wattack(27), 0);
	clear_board();
	board[31] = 5;
	checki("black queen ray", battack(27), 0);
	clear_board();
	board[19] = 1;
	board[3] = 4;
	checki("black rook blocked", battack(27), 1);
	clear_board();
	board[19] = 6;
	checki("black adjacent king", battack(27), 0);
	clear_board();
	board[11] = 6;
	checki("black distant king ignored", battack(27), 1);
	clear_board();
	board[35] = -6;
	checki("white adjacent king", wattack(27), 0);
	clear_board();
	board[43] = -6;
	checki("white distant king ignored", wattack(27), 1);
}

static void
test_attack_order(void)
{
	static int want[] = { 2, -2, 1, 3, -5, -1, -4, 0 };

	clear_board();
	board[12] = 2;
	board[21] = -2;
	board[18] = 1;
	board[20] = 3;
	board[13] = -5;
	board[34] = -1;
	board[3] = -4;
	attack(27);
	check_vec("attack ordering", want);
}

static void
test_attack_quirks(void)
{
	static int empty[] = { 0 };
	static int sliders[] = { 4, -5, 0 };

	clear_board();
	board[37] = 2;
	attack(27);
	check_vec("attack omitted black d1r2", empty);
	clear_board();
	board[37] = -2;
	attack(27);
	check_vec("attack omitted white d1r2", empty);

	clear_board();
	board[26] = -6;
	board[28] = 6;
	attack(27);
	check_vec("attack omits kings", empty);

	clear_board();
	board[28] = 4;
	board[29] = -5;
	board[30] = 2;
	attack(27);
	check_vec("attack scans through sliders", sliders);

	clear_board();
	board[28] = 2;
	board[29] = 4;
	attack(27);
	check_vec("attack non-slider blocks", empty);
}

int
main(void)
{
	init_dirs();
	test_pawns();
	test_knights();
	test_rays_and_kings();
	test_attack_order();
	test_attack_quirks();
	if (failures) {
		printf("attack_check: %d failures\n", failures);
		return 1;
	}
	printf("attack_check: ok\n");
	return 0;
}
