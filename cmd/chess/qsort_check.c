int intrp;

void chess_qsort(int *from, int *to);

int
term(void)
{

	return 0;
}

static void
copy(int *dst, int *src, int n)
{
	int i;

	for (i = 0; i < n; i++)
		dst[i] = src[i];
}

static int
same_records(int *a, int *b, int n)
{
	int i;

	for (i = 0; i < n; i++)
		if (a[i] != b[i])
			return 0;
	return 1;
}

static int
run_case(int *input, int *expected, int n)
{
	int got[16];

	copy(got, input, n);
	chess_qsort(got, got + n);
	return same_records(got, expected, n);
}

int
main(void)
{
	int mixed[] = {
		4, 10,
		-1, 11,
		4, 12,
		0, 13,
		9, 14,
		-3, 15
	};
	int mixed_expected[] = {
		-3, 15,
		-1, 11,
		0, 13,
		4, 12,
		4, 10,
		9, 14
	};
	int equal_two[] = {
		1, 20,
		1, 21
	};
	int equal_two_expected[] = {
		1, 20,
		1, 21
	};
	int equal_three[] = {
		5, 30,
		5, 31,
		5, 32
	};
	int equal_three_expected[] = {
		5, 30,
		5, 31,
		5, 32
	};
	int pivot_moves[] = {
		3, 40,
		1, 41,
		3, 42,
		2, 43,
		3, 44,
		0, 45
	};
	int pivot_moves_expected[] = {
		0, 45,
		1, 41,
		2, 43,
		3, 42,
		3, 44,
		3, 40
	};
	int one[] = { 7, 99 };
	int one_expected[] = { 7, 99 };

	if (!run_case(mixed, mixed_expected, sizeof(mixed) / sizeof(mixed[0])))
		return 1;
	if (!run_case(equal_two, equal_two_expected,
	    sizeof(equal_two) / sizeof(equal_two[0])))
		return 2;
	if (!run_case(equal_three, equal_three_expected,
	    sizeof(equal_three) / sizeof(equal_three[0])))
		return 3;
	if (!run_case(pivot_moves, pivot_moves_expected,
	    sizeof(pivot_moves) / sizeof(pivot_moves[0])))
		return 4;
	if (!run_case(one, one_expected, sizeof(one) / sizeof(one[0])))
		return 5;
	return 0;
}
