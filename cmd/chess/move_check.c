#include <stdio.h>

#include "old.h"

#define	MOVE(f, t)	(((f) << 8) | (t))

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
reset_state(void)
{
	int i;

	clear_board();
	for (i = -6; i <= 6; i++)
		(pval + 6)[i] = i * 100;
	value = 1000;
	flag = 033;
	eppos = 64;
	wkpos = 60;
	bkpos = 4;
	game = 0;
	amp = ambuf;
	*amp++ = -1;
}

static void
check_record(const char *tag, int oldvalue, int oldflag, int oldep,
    int from, int to, int captured, int type)
{
	char name[80];

	snprintf(name, sizeof(name), "%s amp", tag);
	checki(name, amp - ambuf, 8);
	snprintf(name, sizeof(name), "%s old value", tag);
	checki(name, ambuf[1], oldvalue);
	snprintf(name, sizeof(name), "%s old flag", tag);
	checki(name, ambuf[2], oldflag);
	snprintf(name, sizeof(name), "%s old eppos", tag);
	checki(name, ambuf[3], oldep);
	snprintf(name, sizeof(name), "%s from", tag);
	checki(name, ambuf[4], from);
	snprintf(name, sizeof(name), "%s to", tag);
	checki(name, ambuf[5], to);
	snprintf(name, sizeof(name), "%s captured", tag);
	checki(name, ambuf[6], captured);
	snprintf(name, sizeof(name), "%s type", tag);
	checki(name, ambuf[7], type);
}

static void
check_unwound(const char *tag)
{
	char name[80];

	snprintf(name, sizeof(name), "%s amp restored", tag);
	checki(name, amp - ambuf, 1);
}

static void
ordinary_and_capture(void)
{
	reset_state();
	board[57] = -2;
	wmove(MOVE(57, 42));
	checki("white ordinary from", board[57], 0);
	checki("white ordinary to", board[42], -2);
	checki("white ordinary eppos", eppos, -1);
	check_record("white ordinary", 1000, 033, 64, 57, 42, 0, 1);
	wremove();
	checki("white ordinary undo from", board[57], -2);
	checki("white ordinary undo to", board[42], 0);
	check_unwound("white ordinary");

	reset_state();
	board[58] = -3;
	board[30] = 2;
	wmove(MOVE(58, 30));
	checki("white capture value", value, 800);
	check_record("white capture", 1000, 033, 64, 58, 30, 2, 1);
	wremove();
	checki("white capture undo value", value, 1000);
	checki("white capture undo from", board[58], -3);
	checki("white capture undo to", board[30], 2);
	check_unwound("white capture");

	reset_state();
	board[1] = 2;
	bmove(MOVE(1, 18));
	checki("black ordinary from", board[1], 0);
	checki("black ordinary to", board[18], 2);
	checki("black ordinary eppos", eppos, -1);
	check_record("black ordinary", 1000, 033, 64, 1, 18, 0, 1);
	bremove();
	checki("black ordinary undo from", board[1], 2);
	checki("black ordinary undo to", board[18], 0);
	check_unwound("black ordinary");

	reset_state();
	board[2] = 3;
	board[44] = -4;
	bmove(MOVE(2, 44));
	checki("black capture value", value, 1400);
	check_record("black capture", 1000, 033, 64, 2, 44, -4, 1);
	bremove();
	checki("black capture undo value", value, 1000);
	checki("black capture undo from", board[2], 3);
	checki("black capture undo to", board[44], -4);
	check_unwound("black capture");
}

static void
king_moves(void)
{
	reset_state();
	board[60] = -6;
	wmove(MOVE(60, 52));
	checki("white king wkpos", wkpos, 52);
	checki("white king flag", flag, 030);
	checki("white king value", value, 1002);
	check_record("white king", 1000, 033, 64, 60, 52, 0, 0);
	wremove();
	checki("white king undo wkpos", wkpos, 60);
	checki("white king undo value", value, 1000);
	check_unwound("white king");

	reset_state();
	board[4] = 6;
	bmove(MOVE(4, 12));
	checki("black king bkpos", bkpos, 12);
	checki("black king flag", flag, 03);
	checki("black king value", value, 998);
	check_record("black king", 1000, 033, 64, 4, 12, 0, 0);
	bremove();
	checki("black king undo bkpos", bkpos, 4);
	checki("black king undo value", value, 1000);
	check_unwound("black king");
}

static void
castles(void)
{
	reset_state();
	board[60] = -6;
	board[63] = -4;
	wmove(MOVE(60, 62));
	checki("white o-o king", board[62], -6);
	checki("white o-o rook", board[61], -4);
	checki("white o-o old rook", board[63], 0);
	checki("white o-o wkpos", wkpos, 62);
	checki("white o-o flag", flag, 030);
	checki("white o-o value", value, 999);
	check_record("white o-o", 1000, 033, 64, 60, 62, 0, 2);
	wremove();
	checki("white o-o undo king", board[60], -6);
	checki("white o-o undo rook", board[63], -4);
	checki("white o-o undo wkpos", wkpos, 60);
	check_unwound("white o-o");

	reset_state();
	board[60] = -6;
	board[56] = -4;
	wmove(MOVE(60, 58));
	checki("white o-o-o rook", board[59], -4);
	check_record("white o-o-o", 1000, 033, 64, 60, 58, 0, 3);
	wremove();
	checki("white o-o-o undo rook", board[56], -4);
	check_unwound("white o-o-o");

	reset_state();
	board[4] = 6;
	board[7] = 4;
	bmove(MOVE(4, 6));
	checki("black o-o king", board[6], 6);
	checki("black o-o rook", board[5], 4);
	checki("black o-o old rook", board[7], 0);
	checki("black o-o bkpos", bkpos, 6);
	checki("black o-o flag", flag, 03);
	checki("black o-o value", value, 1001);
	check_record("black o-o", 1000, 033, 64, 4, 6, 0, 2);
	bremove();
	checki("black o-o undo king", board[4], 6);
	checki("black o-o undo rook", board[7], 4);
	checki("black o-o undo bkpos", bkpos, 4);
	check_unwound("black o-o");

	reset_state();
	board[4] = 6;
	board[0] = 4;
	bmove(MOVE(4, 2));
	checki("black o-o-o rook", board[3], 4);
	check_record("black o-o-o", 1000, 033, 64, 4, 2, 0, 3);
	bremove();
	checki("black o-o-o undo rook", board[0], 4);
	check_unwound("black o-o-o");
}

static void
enpassant_and_promotion(void)
{
	reset_state();
	board[36] = -1;
	board[35] = 1;
	wmove(MOVE(36, 35));
	checki("white ep encoded to cleared", board[35], 0);
	checki("white ep pawn landing", board[27], -1);
	checki("white ep value", value, 900);
	check_record("white ep", 1000, 033, 64, 36, 35, 1, 4);
	wremove();
	checki("white ep undo from", board[36], -1);
	checki("white ep undo captured", board[35], 1);
	checki("white ep undo landing", board[27], 0);
	check_unwound("white ep");

	reset_state();
	board[27] = 1;
	board[28] = -1;
	bmove(MOVE(27, 28));
	checki("black ep encoded to cleared", board[28], 0);
	checki("black ep pawn landing", board[36], 1);
	checki("black ep value", value, 1100);
	check_record("black ep", 1000, 033, 64, 27, 28, -1, 4);
	bremove();
	checki("black ep undo from", board[27], 1);
	checki("black ep undo captured", board[28], -1);
	checki("black ep undo landing", board[36], 0);
	check_unwound("black ep");

	reset_state();
	board[48] = -1;
	wmove(MOVE(48, 32));
	checki("white double eppos", eppos, 40);
	check_record("white double", 1000, 033, 64, 48, 32, 0, 1);
	wremove();
	checki("white double undo eppos", eppos, 64);
	check_unwound("white double");

	reset_state();
	board[8] = 1;
	bmove(MOVE(8, 24));
	checki("black double eppos", eppos, 16);
	check_record("black double", 1000, 033, 64, 8, 24, 0, 1);
	bremove();
	checki("black double undo eppos", eppos, 64);
	check_unwound("black double");

	reset_state();
	board[8] = -1;
	wmove(MOVE(8, 0));
	checki("white promotion queen", board[0], -5);
	checki("white promotion value", value, 300);
	check_record("white promotion", 1000, 033, 64, 8, 0, 0, 5);
	wremove();
	checki("white promotion undo pawn", board[8], -1);
	checki("white promotion undo value", value, 1000);
	check_unwound("white promotion");

	reset_state();
	board[55] = 1;
	bmove(MOVE(55, 63));
	checki("black promotion queen", board[63], 5);
	checki("black promotion value", value, 1700);
	check_record("black promotion", 1000, 033, 64, 55, 63, 0, 5);
	bremove();
	checki("black promotion undo pawn", board[55], 1);
	checki("black promotion undo value", value, 1000);
	check_unwound("black promotion");
}

static void
rook_flags_and_queens(void)
{
	reset_state();
	board[63] = -4;
	wmove(MOVE(63, 55));
	checki("white h rook flag", flag, 032);
	wremove();
	checki("white h rook flag undo", flag, 033);

	reset_state();
	board[56] = -4;
	wmove(MOVE(56, 48));
	checki("white a rook flag", flag, 031);
	wremove();
	checki("white a rook flag undo", flag, 033);

	reset_state();
	board[7] = 4;
	bmove(MOVE(7, 15));
	checki("black h rook flag", flag, 023);
	bremove();
	checki("black h rook flag undo", flag, 033);

	reset_state();
	board[0] = 4;
	bmove(MOVE(0, 8));
	checki("black a rook flag", flag, 013);
	bremove();
	checki("black a rook flag undo", flag, 033);

	reset_state();
	board[59] = -5;
	wmove(MOVE(59, 51));
	checki("white queen opening value", value, 1001);
	wremove();

	reset_state();
	board[3] = 5;
	bmove(MOVE(3, 11));
	checki("black queen opening value", value, 999);
	bremove();
}

int
main(void)
{

	ordinary_and_capture();
	king_moves();
	castles();
	enpassant_and_promotion();
	rook_flags_and_queens();
	if (failures) {
		printf("move_check: %d failure(s)\n", failures);
		return 1;
	}
	printf("move_check: ok\n");
	return 0;
}
