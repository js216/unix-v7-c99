GAMES_OBJ := $(patsubst %.c,%.o,$(wildcard usr/src/games/*.c))
GAMES = $(patsubst usr/src/games/%.o,usr/games/%,$(GAMES_OBJ))

$(GAMES_OBJ): CPPFLAGS = -Iusr/include -Iusr/src
$(GAMES_OBJ): usr/src/games/games.mk

$(GAMES): usr/games/%: $(CRT) usr/src/games/%.o $(LIBC) | usr/games
	$(LINK)
