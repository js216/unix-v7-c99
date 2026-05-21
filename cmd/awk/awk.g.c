/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison implementation for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* C LALR(1) parser skeleton written by Richard Stallman, by
   simplifying the original so-called "semantic" parser.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

/* All symbols defined below should begin with yy or YY, to avoid
   infringing on user name space.  This should be done even for local
   variables, as they might otherwise be expanded by user macros.
   There are some unavoidable exceptions within include files to
   define necessary library symbols; they are noted "INFRINGES ON
   USER NAME SPACE" below.  */

/* Identify Bison output, and Bison version.  */
#define YYBISON 30802

/* Bison version string.  */
#define YYBISON_VERSION "3.8.2"

/* Skeleton name.  */
#define YYSKELETON_NAME "yacc.c"

/* Pure parsers.  */
#define YYPURE 0

/* Push parsers.  */
#define YYPUSH 0

/* Pull parsers.  */
#define YYPULL 1




/* First part of user prologue.  */
#line 32 "cmd/awk/awk.g.y"

#include "awk.def"
#ifndef	DEBUG
#	define	PUTS(x)
#endif
/* The bison grammar packs node* values through YYSTYPE (=int) without a
 * %union, so the action code below freely converts between int and
 * struct-pointer types.  Scope the warning suppression to this single
 * generated file rather than to all of awk -- the hand-written awk
 * sources are clean. */
#pragma GCC diagnostic ignored "-Wint-conversion"
/* Forward decls for helpers from parse.c/lib.c/b.c. */
extern void free(void *p);
extern int yylex(void);
extern int yyerror(char *s);
extern node *stat2(int a, node *b, node *c);
extern node *stat3(int a, node *b, node *c, node *d);
extern node *stat4(int a, node *b, node *c, node *d, node *e);
extern node *op1(int a, node *b);
extern node *op2(int a, node *b, node *c);
extern node *op3(int a, node *b, node *c, node *d);
extern node *valtonode(cell *a, int b);
extern node *exptostat(node *a);
extern node *genjump(int a);
extern node *genprint(void);
extern node *pa2stat(node *a, node *b, node *c);
extern node *linkum(node *a, node *b);
extern int makedfa(node *a);
extern int startreg(void);
extern int cclenter(char *p);

#line 78 "y.tab.c"

# ifndef YY_CAST
#  ifdef __cplusplus
#   define YY_CAST(Type, Val) static_cast<Type> (Val)
#   define YY_REINTERPRET_CAST(Type, Val) reinterpret_cast<Type> (Val)
#  else
#   define YY_CAST(Type, Val) ((Type) (Val))
#   define YY_REINTERPRET_CAST(Type, Val) ((Type) (Val))
#  endif
# endif
# ifndef YY_NULLPTR
#  if defined __cplusplus
#   if 201103L <= __cplusplus
#    define YY_NULLPTR nullptr
#   else
#    define YY_NULLPTR 0
#   endif
#  else
#   define YY_NULLPTR ((void*)0)
#  endif
# endif


/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    FIRSTTOKEN = 258,              /* FIRSTTOKEN  */
    FINAL = 259,                   /* FINAL  */
    FATAL = 260,                   /* FATAL  */
    LT = 261,                      /* LT  */
    LE = 262,                      /* LE  */
    GT = 263,                      /* GT  */
    GE = 264,                      /* GE  */
    EQ = 265,                      /* EQ  */
    NE = 266,                      /* NE  */
    MATCH = 267,                   /* MATCH  */
    NOTMATCH = 268,                /* NOTMATCH  */
    APPEND = 269,                  /* APPEND  */
    ADD = 270,                     /* ADD  */
    MINUS = 271,                   /* MINUS  */
    MULT = 272,                    /* MULT  */
    DIVIDE = 273,                  /* DIVIDE  */
    MOD = 274,                     /* MOD  */
    UMINUS = 275,                  /* UMINUS  */
    ASSIGN = 276,                  /* ASSIGN  */
    ADDEQ = 277,                   /* ADDEQ  */
    SUBEQ = 278,                   /* SUBEQ  */
    MULTEQ = 279,                  /* MULTEQ  */
    DIVEQ = 280,                   /* DIVEQ  */
    MODEQ = 281,                   /* MODEQ  */
    JUMP = 282,                    /* JUMP  */
    XBEGIN = 283,                  /* XBEGIN  */
    XEND = 284,                    /* XEND  */
    NL = 285,                      /* NL  */
    PRINT = 286,                   /* PRINT  */
    PRINTF = 287,                  /* PRINTF  */
    SPRINTF = 288,                 /* SPRINTF  */
    SPLIT = 289,                   /* SPLIT  */
    IF = 290,                      /* IF  */
    ELSE = 291,                    /* ELSE  */
    WHILE = 292,                   /* WHILE  */
    FOR = 293,                     /* FOR  */
    IN = 294,                      /* IN  */
    NEXT = 295,                    /* NEXT  */
    EXIT = 296,                    /* EXIT  */
    BREAK = 297,                   /* BREAK  */
    CONTINUE = 298,                /* CONTINUE  */
    PROGRAM = 299,                 /* PROGRAM  */
    PASTAT = 300,                  /* PASTAT  */
    PASTAT2 = 301,                 /* PASTAT2  */
    ASGNOP = 302,                  /* ASGNOP  */
    BOR = 303,                     /* BOR  */
    AND = 304,                     /* AND  */
    NOT = 305,                     /* NOT  */
    NUMBER = 306,                  /* NUMBER  */
    VAR = 307,                     /* VAR  */
    ARRAY = 308,                   /* ARRAY  */
    FNCN = 309,                    /* FNCN  */
    SUBSTR = 310,                  /* SUBSTR  */
    LSUBSTR = 311,                 /* LSUBSTR  */
    INDEX = 312,                   /* INDEX  */
    RELOP = 313,                   /* RELOP  */
    MATCHOP = 314,                 /* MATCHOP  */
    OR = 315,                      /* OR  */
    STRING = 316,                  /* STRING  */
    DOT = 317,                     /* DOT  */
    CCL = 318,                     /* CCL  */
    NCCL = 319,                    /* NCCL  */
    CHAR = 320,                    /* CHAR  */
    CAT = 321,                     /* CAT  */
    STAR = 322,                    /* STAR  */
    PLUS = 323,                    /* PLUS  */
    QUEST = 324,                   /* QUEST  */
    POSTINCR = 325,                /* POSTINCR  */
    PREINCR = 326,                 /* PREINCR  */
    POSTDECR = 327,                /* POSTDECR  */
    PREDECR = 328,                 /* PREDECR  */
    INCR = 329,                    /* INCR  */
    DECR = 330,                    /* DECR  */
    FIELD = 331,                   /* FIELD  */
    INDIRECT = 332,                /* INDIRECT  */
    LASTTOKEN = 333                /* LASTTOKEN  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif
/* Token kinds.  */
#define YYEMPTY -2
#define YYEOF 0
#define YYerror 256
#define YYUNDEF 257
#define FIRSTTOKEN 258
#define FINAL 259
#define FATAL 260
#define LT 261
#define LE 262
#define GT 263
#define GE 264
#define EQ 265
#define NE 266
#define MATCH 267
#define NOTMATCH 268
#define APPEND 269
#define ADD 270
#define MINUS 271
#define MULT 272
#define DIVIDE 273
#define MOD 274
#define UMINUS 275
#define ASSIGN 276
#define ADDEQ 277
#define SUBEQ 278
#define MULTEQ 279
#define DIVEQ 280
#define MODEQ 281
#define JUMP 282
#define XBEGIN 283
#define XEND 284
#define NL 285
#define PRINT 286
#define PRINTF 287
#define SPRINTF 288
#define SPLIT 289
#define IF 290
#define ELSE 291
#define WHILE 292
#define FOR 293
#define IN 294
#define NEXT 295
#define EXIT 296
#define BREAK 297
#define CONTINUE 298
#define PROGRAM 299
#define PASTAT 300
#define PASTAT2 301
#define ASGNOP 302
#define BOR 303
#define AND 304
#define NOT 305
#define NUMBER 306
#define VAR 307
#define ARRAY 308
#define FNCN 309
#define SUBSTR 310
#define LSUBSTR 311
#define INDEX 312
#define RELOP 313
#define MATCHOP 314
#define OR 315
#define STRING 316
#define DOT 317
#define CCL 318
#define NCCL 319
#define CHAR 320
#define CAT 321
#define STAR 322
#define PLUS 323
#define QUEST 324
#define POSTINCR 325
#define PREINCR 326
#define POSTDECR 327
#define PREDECR 328
#define INCR 329
#define DECR 330
#define FIELD 331
#define INDIRECT 332
#define LASTTOKEN 333

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
typedef int YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);



/* Symbol kind.  */
enum yysymbol_kind_t
{
  YYSYMBOL_YYEMPTY = -2,
  YYSYMBOL_YYEOF = 0,                      /* "end of file"  */
  YYSYMBOL_YYerror = 1,                    /* error  */
  YYSYMBOL_YYUNDEF = 2,                    /* "invalid token"  */
  YYSYMBOL_FIRSTTOKEN = 3,                 /* FIRSTTOKEN  */
  YYSYMBOL_FINAL = 4,                      /* FINAL  */
  YYSYMBOL_FATAL = 5,                      /* FATAL  */
  YYSYMBOL_LT = 6,                         /* LT  */
  YYSYMBOL_LE = 7,                         /* LE  */
  YYSYMBOL_GT = 8,                         /* GT  */
  YYSYMBOL_GE = 9,                         /* GE  */
  YYSYMBOL_EQ = 10,                        /* EQ  */
  YYSYMBOL_NE = 11,                        /* NE  */
  YYSYMBOL_MATCH = 12,                     /* MATCH  */
  YYSYMBOL_NOTMATCH = 13,                  /* NOTMATCH  */
  YYSYMBOL_APPEND = 14,                    /* APPEND  */
  YYSYMBOL_ADD = 15,                       /* ADD  */
  YYSYMBOL_MINUS = 16,                     /* MINUS  */
  YYSYMBOL_MULT = 17,                      /* MULT  */
  YYSYMBOL_DIVIDE = 18,                    /* DIVIDE  */
  YYSYMBOL_MOD = 19,                       /* MOD  */
  YYSYMBOL_UMINUS = 20,                    /* UMINUS  */
  YYSYMBOL_ASSIGN = 21,                    /* ASSIGN  */
  YYSYMBOL_ADDEQ = 22,                     /* ADDEQ  */
  YYSYMBOL_SUBEQ = 23,                     /* SUBEQ  */
  YYSYMBOL_MULTEQ = 24,                    /* MULTEQ  */
  YYSYMBOL_DIVEQ = 25,                     /* DIVEQ  */
  YYSYMBOL_MODEQ = 26,                     /* MODEQ  */
  YYSYMBOL_JUMP = 27,                      /* JUMP  */
  YYSYMBOL_XBEGIN = 28,                    /* XBEGIN  */
  YYSYMBOL_XEND = 29,                      /* XEND  */
  YYSYMBOL_NL = 30,                        /* NL  */
  YYSYMBOL_PRINT = 31,                     /* PRINT  */
  YYSYMBOL_PRINTF = 32,                    /* PRINTF  */
  YYSYMBOL_SPRINTF = 33,                   /* SPRINTF  */
  YYSYMBOL_SPLIT = 34,                     /* SPLIT  */
  YYSYMBOL_IF = 35,                        /* IF  */
  YYSYMBOL_ELSE = 36,                      /* ELSE  */
  YYSYMBOL_WHILE = 37,                     /* WHILE  */
  YYSYMBOL_FOR = 38,                       /* FOR  */
  YYSYMBOL_IN = 39,                        /* IN  */
  YYSYMBOL_NEXT = 40,                      /* NEXT  */
  YYSYMBOL_EXIT = 41,                      /* EXIT  */
  YYSYMBOL_BREAK = 42,                     /* BREAK  */
  YYSYMBOL_CONTINUE = 43,                  /* CONTINUE  */
  YYSYMBOL_PROGRAM = 44,                   /* PROGRAM  */
  YYSYMBOL_PASTAT = 45,                    /* PASTAT  */
  YYSYMBOL_PASTAT2 = 46,                   /* PASTAT2  */
  YYSYMBOL_ASGNOP = 47,                    /* ASGNOP  */
  YYSYMBOL_BOR = 48,                       /* BOR  */
  YYSYMBOL_AND = 49,                       /* AND  */
  YYSYMBOL_NOT = 50,                       /* NOT  */
  YYSYMBOL_NUMBER = 51,                    /* NUMBER  */
  YYSYMBOL_VAR = 52,                       /* VAR  */
  YYSYMBOL_ARRAY = 53,                     /* ARRAY  */
  YYSYMBOL_FNCN = 54,                      /* FNCN  */
  YYSYMBOL_SUBSTR = 55,                    /* SUBSTR  */
  YYSYMBOL_LSUBSTR = 56,                   /* LSUBSTR  */
  YYSYMBOL_INDEX = 57,                     /* INDEX  */
  YYSYMBOL_RELOP = 58,                     /* RELOP  */
  YYSYMBOL_MATCHOP = 59,                   /* MATCHOP  */
  YYSYMBOL_OR = 60,                        /* OR  */
  YYSYMBOL_STRING = 61,                    /* STRING  */
  YYSYMBOL_DOT = 62,                       /* DOT  */
  YYSYMBOL_CCL = 63,                       /* CCL  */
  YYSYMBOL_NCCL = 64,                      /* NCCL  */
  YYSYMBOL_CHAR = 65,                      /* CHAR  */
  YYSYMBOL_66_ = 66,                       /* '('  */
  YYSYMBOL_67_ = 67,                       /* '^'  */
  YYSYMBOL_68_ = 68,                       /* '$'  */
  YYSYMBOL_CAT = 69,                       /* CAT  */
  YYSYMBOL_70_ = 70,                       /* '+'  */
  YYSYMBOL_71_ = 71,                       /* '-'  */
  YYSYMBOL_72_ = 72,                       /* '*'  */
  YYSYMBOL_73_ = 73,                       /* '/'  */
  YYSYMBOL_74_ = 74,                       /* '%'  */
  YYSYMBOL_STAR = 75,                      /* STAR  */
  YYSYMBOL_PLUS = 76,                      /* PLUS  */
  YYSYMBOL_QUEST = 77,                     /* QUEST  */
  YYSYMBOL_POSTINCR = 78,                  /* POSTINCR  */
  YYSYMBOL_PREINCR = 79,                   /* PREINCR  */
  YYSYMBOL_POSTDECR = 80,                  /* POSTDECR  */
  YYSYMBOL_PREDECR = 81,                   /* PREDECR  */
  YYSYMBOL_INCR = 82,                      /* INCR  */
  YYSYMBOL_DECR = 83,                      /* DECR  */
  YYSYMBOL_FIELD = 84,                     /* FIELD  */
  YYSYMBOL_INDIRECT = 85,                  /* INDIRECT  */
  YYSYMBOL_LASTTOKEN = 86,                 /* LASTTOKEN  */
  YYSYMBOL_87_ = 87,                       /* '{'  */
  YYSYMBOL_88_ = 88,                       /* '}'  */
  YYSYMBOL_89_ = 89,                       /* ')'  */
  YYSYMBOL_90_ = 90,                       /* '['  */
  YYSYMBOL_91_ = 91,                       /* ']'  */
  YYSYMBOL_92_ = 92,                       /* ','  */
  YYSYMBOL_93_ = 93,                       /* '|'  */
  YYSYMBOL_94_ = 94,                       /* ';'  */
  YYSYMBOL_YYACCEPT = 95,                  /* $accept  */
  YYSYMBOL_program = 96,                   /* program  */
  YYSYMBOL_begin = 97,                     /* begin  */
  YYSYMBOL_end = 98,                       /* end  */
  YYSYMBOL_compound_conditional = 99,      /* compound_conditional  */
  YYSYMBOL_compound_pattern = 100,         /* compound_pattern  */
  YYSYMBOL_conditional = 101,              /* conditional  */
  YYSYMBOL_else = 102,                     /* else  */
  YYSYMBOL_field = 103,                    /* field  */
  YYSYMBOL_if = 104,                       /* if  */
  YYSYMBOL_lex_expr = 105,                 /* lex_expr  */
  YYSYMBOL_var = 106,                      /* var  */
  YYSYMBOL_term = 107,                     /* term  */
  YYSYMBOL_expr = 108,                     /* expr  */
  YYSYMBOL_optNL = 109,                    /* optNL  */
  YYSYMBOL_pa_stat = 110,                  /* pa_stat  */
  YYSYMBOL_pa_stats = 111,                 /* pa_stats  */
  YYSYMBOL_pattern = 112,                  /* pattern  */
  YYSYMBOL_print_list = 113,               /* print_list  */
  YYSYMBOL_pe_list = 114,                  /* pe_list  */
  YYSYMBOL_redir = 115,                    /* redir  */
  YYSYMBOL_regular_expr = 116,             /* regular_expr  */
  YYSYMBOL_117_1 = 117,                    /* $@1  */
  YYSYMBOL_r = 118,                        /* r  */
  YYSYMBOL_rel_expr = 119,                 /* rel_expr  */
  YYSYMBOL_st = 120,                       /* st  */
  YYSYMBOL_simple_stat = 121,              /* simple_stat  */
  YYSYMBOL_statement = 122,                /* statement  */
  YYSYMBOL_stat_list = 123,                /* stat_list  */
  YYSYMBOL_while = 124,                    /* while  */
  YYSYMBOL_for = 125                       /* for  */
};
typedef enum yysymbol_kind_t yysymbol_kind_t;




#ifdef short
# undef short
#endif

/* On compilers that do not define __PTRDIFF_MAX__ etc., make sure
   <limits.h> and (if available) <stdint.h> are included
   so that the code can choose integer types of a good width.  */

#ifndef __PTRDIFF_MAX__
# include <limits.h> /* INFRINGES ON USER NAME SPACE */
# if defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stdint.h> /* INFRINGES ON USER NAME SPACE */
#  define YY_STDINT_H
# endif
#endif

/* Narrow types that promote to a signed type and that can represent a
   signed or unsigned integer of at least N bits.  In tables they can
   save space and decrease cache pressure.  Promoting to a signed type
   helps avoid bugs in integer arithmetic.  */

#ifdef __INT_LEAST8_MAX__
typedef __INT_LEAST8_TYPE__ yytype_int8;
#elif defined YY_STDINT_H
typedef int_least8_t yytype_int8;
#else
typedef signed char yytype_int8;
#endif

#ifdef __INT_LEAST16_MAX__
typedef __INT_LEAST16_TYPE__ yytype_int16;
#elif defined YY_STDINT_H
typedef int_least16_t yytype_int16;
#else
typedef short yytype_int16;
#endif

/* Work around bug in HP-UX 11.23, which defines these macros
   incorrectly for preprocessor constants.  This workaround can likely
   be removed in 2023, as HPE has promised support for HP-UX 11.23
   (aka HP-UX 11i v2) only through the end of 2022; see Table 2 of
   <https://h20195.www2.hpe.com/V2/getpdf.aspx/4AA4-7673ENW.pdf>.  */
#ifdef __hpux
# undef UINT_LEAST8_MAX
# undef UINT_LEAST16_MAX
# define UINT_LEAST8_MAX 255
# define UINT_LEAST16_MAX 65535
#endif

#if defined __UINT_LEAST8_MAX__ && __UINT_LEAST8_MAX__ <= __INT_MAX__
typedef __UINT_LEAST8_TYPE__ yytype_uint8;
#elif (!defined __UINT_LEAST8_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST8_MAX <= INT_MAX)
typedef uint_least8_t yytype_uint8;
#elif !defined __UINT_LEAST8_MAX__ && UCHAR_MAX <= INT_MAX
typedef unsigned char yytype_uint8;
#else
typedef short yytype_uint8;
#endif

#if defined __UINT_LEAST16_MAX__ && __UINT_LEAST16_MAX__ <= __INT_MAX__
typedef __UINT_LEAST16_TYPE__ yytype_uint16;
#elif (!defined __UINT_LEAST16_MAX__ && defined YY_STDINT_H \
       && UINT_LEAST16_MAX <= INT_MAX)
typedef uint_least16_t yytype_uint16;
#elif !defined __UINT_LEAST16_MAX__ && USHRT_MAX <= INT_MAX
typedef unsigned short yytype_uint16;
#else
typedef int yytype_uint16;
#endif

#ifndef YYPTRDIFF_T
# if defined __PTRDIFF_TYPE__ && defined __PTRDIFF_MAX__
#  define YYPTRDIFF_T __PTRDIFF_TYPE__
#  define YYPTRDIFF_MAXIMUM __PTRDIFF_MAX__
# elif defined PTRDIFF_MAX
#  ifndef ptrdiff_t
#   include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  endif
#  define YYPTRDIFF_T ptrdiff_t
#  define YYPTRDIFF_MAXIMUM PTRDIFF_MAX
# else
#  define YYPTRDIFF_T long
#  define YYPTRDIFF_MAXIMUM LONG_MAX
# endif
#endif

#ifndef YYSIZE_T
# ifdef __SIZE_TYPE__
#  define YYSIZE_T __SIZE_TYPE__
# elif defined size_t
#  define YYSIZE_T size_t
# elif defined __STDC_VERSION__ && 199901 <= __STDC_VERSION__
#  include <stddef.h> /* INFRINGES ON USER NAME SPACE */
#  define YYSIZE_T size_t
# else
#  define YYSIZE_T unsigned
# endif
#endif

#define YYSIZE_MAXIMUM                                  \
  YY_CAST (YYPTRDIFF_T,                                 \
           (YYPTRDIFF_MAXIMUM < YY_CAST (YYSIZE_T, -1)  \
            ? YYPTRDIFF_MAXIMUM                         \
            : YY_CAST (YYSIZE_T, -1)))

#define YYSIZEOF(X) YY_CAST (YYPTRDIFF_T, sizeof (X))


/* Stored state numbers (used for stacks). */
typedef yytype_uint8 yy_state_t;

/* State numbers in computations.  */
typedef int yy_state_fast_t;

#ifndef YY_
# if defined YYENABLE_NLS && YYENABLE_NLS
#  if ENABLE_NLS
#   include <libintl.h> /* INFRINGES ON USER NAME SPACE */
#   define YY_(Msgid) dgettext ("bison-runtime", Msgid)
#  endif
# endif
# ifndef YY_
#  define YY_(Msgid) Msgid
# endif
#endif


#ifndef YY_ATTRIBUTE_PURE
# if defined __GNUC__ && 2 < __GNUC__ + (96 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_PURE __attribute__ ((__pure__))
# else
#  define YY_ATTRIBUTE_PURE
# endif
#endif

#ifndef YY_ATTRIBUTE_UNUSED
# if defined __GNUC__ && 2 < __GNUC__ + (7 <= __GNUC_MINOR__)
#  define YY_ATTRIBUTE_UNUSED __attribute__ ((__unused__))
# else
#  define YY_ATTRIBUTE_UNUSED
# endif
#endif

/* Suppress unused-variable warnings by "using" E.  */
#if ! defined lint || defined __GNUC__
# define YY_USE(E) ((void) (E))
#else
# define YY_USE(E) /* empty */
#endif

/* Suppress an incorrect diagnostic about yylval being uninitialized.  */
#if defined __GNUC__ && ! defined __ICC && 406 <= __GNUC__ * 100 + __GNUC_MINOR__
# if __GNUC__ * 100 + __GNUC_MINOR__ < 407
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")
# else
#  define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN                           \
    _Pragma ("GCC diagnostic push")                                     \
    _Pragma ("GCC diagnostic ignored \"-Wuninitialized\"")              \
    _Pragma ("GCC diagnostic ignored \"-Wmaybe-uninitialized\"")
# endif
# define YY_IGNORE_MAYBE_UNINITIALIZED_END      \
    _Pragma ("GCC diagnostic pop")
#else
# define YY_INITIAL_VALUE(Value) Value
#endif
#ifndef YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
# define YY_IGNORE_MAYBE_UNINITIALIZED_END
#endif
#ifndef YY_INITIAL_VALUE
# define YY_INITIAL_VALUE(Value) /* Nothing. */
#endif

#if defined __cplusplus && defined __GNUC__ && ! defined __ICC && 6 <= __GNUC__
# define YY_IGNORE_USELESS_CAST_BEGIN                          \
    _Pragma ("GCC diagnostic push")                            \
    _Pragma ("GCC diagnostic ignored \"-Wuseless-cast\"")
# define YY_IGNORE_USELESS_CAST_END            \
    _Pragma ("GCC diagnostic pop")
#endif
#ifndef YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_BEGIN
# define YY_IGNORE_USELESS_CAST_END
#endif


#define YY_ASSERT(E) ((void) (0 && (E)))

#if !defined yyoverflow

/* The parser invokes alloca or malloc; define the necessary symbols.  */

# ifdef YYSTACK_USE_ALLOCA
#  if YYSTACK_USE_ALLOCA
#   ifdef __GNUC__
#    define YYSTACK_ALLOC __builtin_alloca
#   elif defined __BUILTIN_VA_ARG_INCR
#    include <alloca.h> /* INFRINGES ON USER NAME SPACE */
#   elif defined _AIX
#    define YYSTACK_ALLOC __alloca
#   elif defined _MSC_VER
#    include <malloc.h> /* INFRINGES ON USER NAME SPACE */
#    define alloca _alloca
#   else
#    define YYSTACK_ALLOC alloca
#    if ! defined _ALLOCA_H && ! defined EXIT_SUCCESS
#     include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
      /* Use EXIT_SUCCESS as a witness for stdlib.h.  */
#     ifndef EXIT_SUCCESS
#      define EXIT_SUCCESS 0
#     endif
#    endif
#   endif
#  endif
# endif

# ifdef YYSTACK_ALLOC
   /* Pacify GCC's 'empty if-body' warning.  */
#  define YYSTACK_FREE(Ptr) do { /* empty */; } while (0)
#  ifndef YYSTACK_ALLOC_MAXIMUM
    /* The OS might guarantee only one guard page at the bottom of the stack,
       and a page size can be as small as 4096 bytes.  So we cannot safely
       invoke alloca (N) if N exceeds 4096.  Use a slightly smaller number
       to allow for a few compiler-allocated temporary stack slots.  */
#   define YYSTACK_ALLOC_MAXIMUM 4032 /* reasonable circa 2006 */
#  endif
# else
#  define YYSTACK_ALLOC YYMALLOC
#  define YYSTACK_FREE YYFREE
#  ifndef YYSTACK_ALLOC_MAXIMUM
#   define YYSTACK_ALLOC_MAXIMUM YYSIZE_MAXIMUM
#  endif
#  if (defined __cplusplus && ! defined EXIT_SUCCESS \
       && ! ((defined YYMALLOC || defined malloc) \
             && (defined YYFREE || defined free)))
#   include <stdlib.h> /* INFRINGES ON USER NAME SPACE */
#   ifndef EXIT_SUCCESS
#    define EXIT_SUCCESS 0
#   endif
#  endif
#  ifndef YYMALLOC
#   define YYMALLOC malloc
#   if ! defined malloc && ! defined EXIT_SUCCESS
void *malloc (YYSIZE_T); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
#  ifndef YYFREE
#   define YYFREE free
#   if ! defined free && ! defined EXIT_SUCCESS
void free (void *); /* INFRINGES ON USER NAME SPACE */
#   endif
#  endif
# endif
#endif /* !defined yyoverflow */

#if (! defined yyoverflow \
     && (! defined __cplusplus \
         || (defined YYSTYPE_IS_TRIVIAL && YYSTYPE_IS_TRIVIAL)))

/* A type that is properly aligned for any stack member.  */
union yyalloc
{
  yy_state_t yyss_alloc;
  YYSTYPE yyvs_alloc;
};

/* The size of the maximum gap between one aligned stack and the next.  */
# define YYSTACK_GAP_MAXIMUM (YYSIZEOF (union yyalloc) - 1)

/* The size of an array large to enough to hold all stacks, each with
   N elements.  */
# define YYSTACK_BYTES(N) \
     ((N) * (YYSIZEOF (yy_state_t) + YYSIZEOF (YYSTYPE)) \
      + YYSTACK_GAP_MAXIMUM)

# define YYCOPY_NEEDED 1

/* Relocate STACK from its old location to the new one.  The
   local variables YYSIZE and YYSTACKSIZE give the old and new number of
   elements in the stack, and YYPTR gives the new location of the
   stack.  Advance YYPTR to a properly aligned location for the next
   stack.  */
# define YYSTACK_RELOCATE(Stack_alloc, Stack)                           \
    do                                                                  \
      {                                                                 \
        YYPTRDIFF_T yynewbytes;                                         \
        YYCOPY (&yyptr->Stack_alloc, Stack, yysize);                    \
        Stack = &yyptr->Stack_alloc;                                    \
        yynewbytes = yystacksize * YYSIZEOF (*Stack) + YYSTACK_GAP_MAXIMUM; \
        yyptr += yynewbytes / YYSIZEOF (*yyptr);                        \
      }                                                                 \
    while (0)

#endif

#if defined YYCOPY_NEEDED && YYCOPY_NEEDED
/* Copy COUNT objects from SRC to DST.  The source and destination do
   not overlap.  */
# ifndef YYCOPY
#  if defined __GNUC__ && 1 < __GNUC__
#   define YYCOPY(Dst, Src, Count) \
      __builtin_memcpy (Dst, Src, YY_CAST (YYSIZE_T, (Count)) * sizeof (*(Src)))
#  else
#   define YYCOPY(Dst, Src, Count)              \
      do                                        \
        {                                       \
          YYPTRDIFF_T yyi;                      \
          for (yyi = 0; yyi < (Count); yyi++)   \
            (Dst)[yyi] = (Src)[yyi];            \
        }                                       \
      while (0)
#  endif
# endif
#endif /* !YYCOPY_NEEDED */

/* YYFINAL -- State number of the termination state.  */
#define YYFINAL  6
/* YYLAST -- Last index in YYTABLE.  */
#define YYLAST   1587

/* YYNTOKENS -- Number of terminals.  */
#define YYNTOKENS  95
/* YYNNTS -- Number of nonterminals.  */
#define YYNNTS  31
/* YYNRULES -- Number of rules.  */
#define YYNRULES  120
/* YYNSTATES -- Number of states.  */
#define YYNSTATES  240

/* YYMAXUTOK -- Last valid token kind.  */
#define YYMAXUTOK   333


/* YYTRANSLATE(TOKEN-NUM) -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex, with out-of-bounds checking.  */
#define YYTRANSLATE(YYX)                                \
  (0 <= (YYX) && (YYX) <= YYMAXUTOK                     \
   ? YY_CAST (yysymbol_kind_t, yytranslate[YYX])        \
   : YYSYMBOL_YYUNDEF)

/* YYTRANSLATE[TOKEN-NUM] -- Symbol number corresponding to TOKEN-NUM
   as returned by yylex.  */
static const yytype_int8 yytranslate[] =
{
       0,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,    68,    74,     2,     2,
      66,    89,    72,    70,    92,    71,     2,    73,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,    94,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,    90,     2,    91,    67,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,    87,    93,    88,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     2,     2,     2,     2,
       2,     2,     2,     2,     2,     2,     1,     2,     3,     4,
       5,     6,     7,     8,     9,    10,    11,    12,    13,    14,
      15,    16,    17,    18,    19,    20,    21,    22,    23,    24,
      25,    26,    27,    28,    29,    30,    31,    32,    33,    34,
      35,    36,    37,    38,    39,    40,    41,    42,    43,    44,
      45,    46,    47,    48,    49,    50,    51,    52,    53,    54,
      55,    56,    57,    58,    59,    60,    61,    62,    63,    64,
      65,    69,    75,    76,    77,    78,    79,    80,    81,    82,
      83,    84,    85,    86
};

#if YYDEBUG
/* YYRLINE[YYN] -- Source line where rule number YYN was defined.  */
static const yytype_int16 yyrline[] =
{
       0,    41,    41,    42,    46,    47,    48,    52,    53,    54,
      58,    59,    60,    61,    65,    66,    67,    68,    72,    73,
      74,    75,    79,    83,    84,    88,    92,    93,    97,    98,
      99,   100,   101,   104,   105,   108,   111,   112,   113,   115,
     117,   119,   121,   123,   124,   125,   126,   127,   128,   129,
     130,   131,   132,   133,   134,   138,   139,   140,   144,   145,
     149,   150,   151,   152,   154,   158,   159,   160,   164,   167,
     170,   171,   172,   176,   177,   181,   182,   183,   187,   188,
     192,   192,   198,   199,   200,   201,   202,   203,   204,   205,
     207,   208,   209,   210,   214,   216,   221,   222,   226,   228,
     230,   232,   234,   235,   236,   240,   241,   242,   244,   245,
     246,   247,   248,   249,   250,   254,   255,   259,   263,   265,
     267
};
#endif

/** Accessing symbol of state STATE.  */
#define YY_ACCESSING_SYMBOL(State) YY_CAST (yysymbol_kind_t, yystos[State])

#if YYDEBUG || 0
/* The user-facing name of the symbol whose (internal) number is
   YYSYMBOL.  No bounds checking.  */
static const char *yysymbol_name (yysymbol_kind_t yysymbol) YY_ATTRIBUTE_UNUSED;

/* YYTNAME[SYMBOL-NUM] -- String name of the symbol SYMBOL-NUM.
   First, the terminals, then, starting at YYNTOKENS, nonterminals.  */
static const char *const yytname[] =
{
  "\"end of file\"", "error", "\"invalid token\"", "FIRSTTOKEN", "FINAL",
  "FATAL", "LT", "LE", "GT", "GE", "EQ", "NE", "MATCH", "NOTMATCH",
  "APPEND", "ADD", "MINUS", "MULT", "DIVIDE", "MOD", "UMINUS", "ASSIGN",
  "ADDEQ", "SUBEQ", "MULTEQ", "DIVEQ", "MODEQ", "JUMP", "XBEGIN", "XEND",
  "NL", "PRINT", "PRINTF", "SPRINTF", "SPLIT", "IF", "ELSE", "WHILE",
  "FOR", "IN", "NEXT", "EXIT", "BREAK", "CONTINUE", "PROGRAM", "PASTAT",
  "PASTAT2", "ASGNOP", "BOR", "AND", "NOT", "NUMBER", "VAR", "ARRAY",
  "FNCN", "SUBSTR", "LSUBSTR", "INDEX", "RELOP", "MATCHOP", "OR", "STRING",
  "DOT", "CCL", "NCCL", "CHAR", "'('", "'^'", "'$'", "CAT", "'+'", "'-'",
  "'*'", "'/'", "'%'", "STAR", "PLUS", "QUEST", "POSTINCR", "PREINCR",
  "POSTDECR", "PREDECR", "INCR", "DECR", "FIELD", "INDIRECT", "LASTTOKEN",
  "'{'", "'}'", "')'", "'['", "']'", "','", "'|'", "';'", "$accept",
  "program", "begin", "end", "compound_conditional", "compound_pattern",
  "conditional", "else", "field", "if", "lex_expr", "var", "term", "expr",
  "optNL", "pa_stat", "pa_stats", "pattern", "print_list", "pe_list",
  "redir", "regular_expr", "$@1", "r", "rel_expr", "st", "simple_stat",
  "statement", "stat_list", "while", "for", YY_NULLPTR
};

static const char *
yysymbol_name (yysymbol_kind_t yysymbol)
{
  return yytname[yysymbol];
}
#endif

#define YYPACT_NINF (-103)

#define yypact_value_is_default(Yyn) \
  ((Yyn) == YYPACT_NINF)

#define YYTABLE_NINF (-104)

#define yytable_value_is_error(Yyn) \
  0

/* YYPACT[STATE-NUM] -- Index in YYTABLE of the portion describing
   STATE-NUM.  */
static const yytype_int16 yypact[] =
{
     798,  -103,   -58,    48,    10,  -103,  -103,  -103,  1108,   314,
     -37,  1445,   -12,  1363,  -103,   -23,     5,    11,    15,  -103,
    1363,  1480,  1480,  -103,   132,   132,  -103,  1480,  -103,    32,
    -103,  -103,  -103,    -4,   107,  1398,   -28,   -22,  -103,  -103,
    -103,  1445,  1445,    19,    44,    47,   -28,   -28,   -28,   -28,
    1480,  -103,  -103,   710,  1480,   -28,  -103,   710,  -103,  -103,
    1445,   952,  -103,   -18,  1480,  -103,  1480,  1190,  1480,  1480,
       3,    28,  1151,    40,    34,    12,  -103,  -103,   227,  -103,
    -103,  -103,   380,  -103,  1480,  -103,  -103,  1480,  1480,  1480,
    1480,  1480,  1480,    54,   107,  -103,  -103,  -103,  1363,  1363,
    -103,  1363,   -13,   -13,  1437,  1437,   217,  -103,  -103,  -103,
    -103,  1198,   446,   101,  -103,  -103,   512,   874,   -81,  1480,
    1480,   991,  1116,  -103,  1237,  1030,  1069,  -103,  -103,  -103,
    -103,  -103,  -103,  -103,  -103,   227,  -103,  -103,  1510,  -103,
    1480,    26,    26,  -103,  -103,  -103,   251,  -103,    93,  -103,
     578,   -34,  -103,  -103,  1480,  1480,  1437,  1437,  -103,   -26,
    -103,  1398,  -103,    -2,   -33,    51,  -103,   111,   710,  -103,
    -103,  1480,  1480,    98,  -103,  -103,  1480,  1480,  1492,   227,
    -103,  -103,  -103,  -103,   -57,  -103,  -103,  1480,  1480,  -103,
      62,    71,    28,  1151,    34,  1437,  1437,   111,   111,   100,
     839,  -103,  -103,  -103,   -20,   913,  1276,  -103,   168,   644,
    -103,   104,  -103,  -103,  -103,    66,   754,   -39,  -103,  1480,
    -103,  1480,  -103,  -103,   111,    67,   754,  1284,  1323,   710,
     111,    72,  -103,  -103,  -103,   710,   111,  -103,   710,  -103
};

/* YYDEFACT[STATE-NUM] -- Default reduction number in state STATE-NUM.
   Performed when YYTABLE does not specify something else to do.  Zero
   means the default is an error.  */
static const yytype_int8 yydefact[] =
{
       0,     3,     0,     0,    66,   116,     1,     5,     9,     0,
       0,     0,     0,     0,    28,    30,    34,     0,     0,    29,
       0,     0,     0,    80,     0,     0,    23,     0,   116,     2,
      72,    32,    71,    33,    55,    69,    67,    60,    68,    70,
     104,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,   116,     4,     0,   102,     0,   115,     0,   109,   116,
       0,    73,    37,    74,     0,    16,     0,     0,     0,     0,
      72,    71,    69,     0,    70,    33,    50,    49,     0,    51,
      52,    24,     0,     8,     0,    53,    54,     0,     0,     0,
       0,     0,     0,     0,    56,    96,    97,    65,     0,     0,
     116,     0,    99,   101,     0,     0,     0,   110,   111,   112,
     113,     0,     0,   106,   105,   108,     0,     0,     0,     0,
       0,     0,     0,    35,     0,     0,     0,    17,    27,    43,
      95,    83,    84,    85,    82,     0,    86,    87,     0,    64,
      57,    44,    45,    46,    47,    48,    94,    26,    14,    15,
       0,    62,    78,    79,     0,     0,     0,     0,    21,     0,
      20,    18,    19,     0,    30,     0,   114,    59,     0,     7,
      77,    75,    76,     0,    31,    36,     0,     0,     0,     0,
      81,    90,    91,    92,    89,    61,   116,    98,   100,    12,
      21,     0,    20,    18,    19,     0,     0,    59,    59,     0,
       0,    58,    22,   107,     0,     0,     0,    93,    88,     0,
      13,    10,    11,    25,   117,     0,     0,     0,    41,     0,
      39,     0,    42,    63,    59,     0,     0,     0,     0,     0,
      59,     0,    40,    38,   120,     0,    59,   119,     0,   118
};

/* YYPGOTO[NTERM-NUM].  */
static const yytype_int16 yypgoto[] =
{
    -103,  -103,  -103,  -103,     7,   142,   -74,  -103,  -103,  -103,
       8,    14,   136,    -8,   -54,  -103,  -103,    31,    92,   106,
      64,    79,  -103,   -71,    17,   157,  -102,   -40,   -27,  -103,
    -103
};

/* YYDEFGOTO[NTERM-NUM].  */
static const yytype_uint8 yydefgoto[] =
{
       0,     3,     4,    29,   158,    30,   159,   168,    31,    53,
     160,    33,    34,    54,   202,    36,     8,    37,    62,    63,
     154,    38,    78,   184,   162,    97,    55,    56,     9,    57,
      58
};

/* YYTABLE[YYPACT[STATE-NUM]] -- What to do in state STATE-NUM.  If
   positive, shift that token.  If negative, reduce the rule whose
   number is the opposite.  If YYTABLE_NINF, syntax error.  */
static const yytype_int16 yytable[] =
{
      35,    82,    95,    61,   165,    35,   199,   138,   170,   195,
     196,   120,    72,   113,    98,    99,    32,   115,   181,   182,
     183,    32,   195,   196,   112,    39,    98,    99,    71,     5,
      39,   163,   116,    61,    61,    75,    75,    74,    79,    80,
       7,    75,   111,    84,    65,   152,   195,   196,     6,    75,
      59,    73,   117,   186,    64,   226,   121,    66,   122,   124,
     125,   126,    83,   197,   178,   100,    96,    66,    75,   218,
     101,    67,   219,   150,   120,    75,   140,    68,    85,    86,
     153,    69,   189,   191,   146,   104,    75,   198,    98,    99,
      35,    35,   127,    35,    85,    86,   161,   161,    89,    90,
      91,    75,    75,    75,    75,    75,    32,    32,   208,    32,
     105,   171,   172,   106,   225,    39,    39,   128,    39,   195,
     196,   211,   212,   130,   231,    75,   217,    23,   203,   148,
     149,    75,   151,   102,   103,    75,    75,   167,    75,    75,
      75,   201,    99,   213,   214,   200,   187,   188,   161,   193,
     204,   210,   215,   196,    75,   224,   230,    76,    77,   209,
      75,   236,    70,    81,   190,   192,   118,   155,   205,   206,
     229,    94,   147,     0,   194,    75,   235,    87,    88,    89,
      90,    91,   238,    14,    15,    75,    75,   161,   161,   234,
      94,     0,   161,    19,     0,   237,     0,    94,   239,     0,
       0,    75,    75,   107,   108,   109,   110,    75,    94,     0,
       0,   227,   114,   228,     0,     0,    26,    27,    40,    75,
      75,     0,     0,   141,   142,   143,   144,   145,     0,     0,
     131,   132,   133,   134,   135,   136,   137,     0,     0,     0,
       0,    75,    75,   181,   182,   183,     0,    94,    41,    42,
      11,    12,     0,    94,     0,     0,     0,    94,    94,     0,
      94,    94,    94,     0,     0,     0,     0,     0,    14,   164,
       0,    16,    17,     0,    18,     0,    94,     0,    19,     0,
       0,     0,    94,    50,    11,    12,     0,    21,    22,   131,
     132,   133,   134,   135,   136,   137,     0,    94,     0,    24,
      25,    26,    27,     0,     0,     0,     0,    94,    94,     0,
       0,  -103,    19,     0,     0,    40,     0,    50,     0,     0,
       0,    21,    22,    94,    94,     0,     0,     0,     0,    94,
       0,     0,     0,    24,    25,    26,    27,     0,     0,     0,
       0,    94,    94,     0,  -103,    41,    42,    11,    12,    43,
       0,    44,    45,     0,    46,    47,    48,    49,     0,     0,
       0,     0,     0,    94,    94,    14,    15,     0,    16,    17,
       0,    18,     0,     0,     0,    19,     0,     0,     0,     0,
      50,    40,     0,     0,    21,    22,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,    24,    25,    26,    27,
       0,    51,    52,     0,     0,     0,     0,     0,  -103,     0,
    -103,    41,    42,    11,    12,    43,     0,    44,    45,     0,
      46,    47,    48,    49,     0,     0,     0,     0,     0,     0,
       0,    14,    15,     0,    16,    17,     0,    18,     0,     0,
       0,    19,     0,     0,     0,     0,    50,    40,     0,     0,
      21,    22,     0,     0,     0,     0,     0,     0,     0,     0,
       0,     0,    24,    25,    26,    27,     0,    51,   139,     0,
       0,     0,     0,     0,  -103,     0,  -103,    41,    42,    11,
      12,    43,     0,    44,    45,     0,    46,    47,    48,    49,
       0,     0,     0,     0,     0,     0,     0,    14,    15,     0,
      16,    17,     0,    18,     0,     0,     0,    19,     0,     0,
       0,     0,    50,    40,     0,     0,    21,    22,     0,     0,
       0,     0,     0,     0,     0,     0,     0,     0,    24,    25,
      26,    27,     0,    51,   166,     0,     0,     0,     0,     0,
    -103,     0,  -103,    41,    42,    11,    12,    43,     0,    44,
      45,     0,    46,    47,    48,    49,     0,     0,     0,     0,
       0,     0,     0,    14,    15,     0,    16,    17,     0,    18,
       0,     0,     0,    19,     0,     0,     0,     0,    50,    40,
       0,     0,    21,    22,     0,     0,     0,     0,     0,     0,
       0,     0,     0,     0,    24,    25,    26,    27,     0,    51,
     169,     0,     0,     0,     0,     0,  -103,     0,  -103,    41,
      42,    11,    12,    43,     0,    44,    45,     0,    46,    47,
      48,    49,     0,     0,     0,     0,     0,     0,     0,    14,
      15,     0,    16,    17,     0,    18,     0,     0,     0,    19,
       0,     0,     0,     0,    50,    40,     0,     0,    21,    22,
       0,     0,     0,     0,     0,     0,     0,     0,     0,     0,
      24,    25,    26,    27,     0,    51,   185,     0,     0,     0,
       0,     0,  -103,     0,  -103,    41,    42,    11,    12,    43,
       0,    44,    45,     0,    46,    47,    48,    49,     0,     0,
       0,     0,     0,     0,     0,    14,    15,     0,    16,    17,
       0,    18,     0,     0,     0,    19,     0,     0,     0,     0,
      50,    40,     0,     0,    21,    22,     0,     0,     0,     0,
       0,     0,     0,     0,     0,     0,    24,    25,    26,    27,
       0,    51,   223,     0,     0,     0,     0,     0,  -103,     0,
    -103,    41,    42,    11,    12,    43,     0,    44,    45,     0,
      46,    47,    48,    49,     0,    40,     0,     0,     0,     0,
       0,    14,    15,     0,    16,    17,     0,    18,     0,     0,
       0,    19,     0,     0,     0,     0,    50,     0,     0,     0,
      21,    22,     0,     0,     0,    41,    42,    11,    12,     0,
       0,     0,    24,    25,    26,    27,     0,    51,    -6,     1,
       0,     0,     0,     0,  -103,    14,    15,     0,    16,    17,
       0,    18,     0,     0,     0,    19,     0,     0,     0,     0,
      50,     0,     0,     0,    21,    22,     2,    -6,    -6,     0,
       0,    -6,    -6,     0,     0,     0,    24,    25,    26,    27,
       0,     0,     0,  -103,     0,     0,     0,     0,    -6,    -6,
      -6,     0,    -6,    -6,     0,    -6,     0,     0,     0,    -6,
       0,     0,     0,     0,    -6,     0,     0,     0,    -6,    -6,
       0,    -6,    11,    12,     0,     0,     0,     0,     0,     0,
      -6,    -6,    -6,    -6,     0,    -6,     0,     0,     0,   156,
      14,    15,     0,    16,    17,     0,    18,     0,     0,     0,
      19,     0,     0,     0,     0,   157,     0,    11,    12,    21,
      22,     0,     0,     0,     0,     0,     0,     0,     0,     0,
       0,    24,    25,    26,    27,    14,    15,     0,    16,    17,
       0,    18,     0,   216,     0,    19,     0,     0,     0,     0,
      50,     0,     0,     0,    21,    22,    11,    12,     0,     0,
       0,     0,     0,     0,     0,     0,    24,    25,    26,    27,
       0,     0,     0,   129,    14,    15,   119,    16,    17,     0,
      18,     0,     0,     0,    19,     0,     0,     0,     0,    50,
       0,     0,     0,    21,    22,    11,    12,     0,     0,     0,
       0,     0,     0,     0,     0,    24,    25,    26,    27,     0,
       0,     0,   220,    14,    15,   221,    16,    17,     0,    18,
       0,     0,     0,    19,     0,     0,     0,     0,    50,     0,
       0,     0,    21,    22,    11,    12,     0,     0,     0,     0,
       0,     0,     0,     0,    24,    25,    26,    27,     0,     0,
       0,     0,    14,    15,   119,    16,    17,     0,    18,     0,
       0,     0,    19,     0,     0,     0,     0,    50,     0,     0,
       0,    21,    22,    11,    12,     0,     0,     0,     0,     0,
       0,     0,     0,    24,    25,    26,    27,     0,     0,     0,
       0,    14,    15,   173,    16,    17,     0,    18,     0,     0,
       0,    19,     0,     0,     0,     0,    50,     0,     0,     0,
      21,    22,    11,    12,     0,     0,     0,     0,     0,     0,
       0,     0,    24,    25,    26,    27,     0,     0,     0,     0,
      14,    15,   176,    16,    17,     0,    18,     0,     0,     0,
      19,     0,     0,     0,     0,    50,     0,    10,     0,    21,
      22,    11,    12,     0,     0,     0,     0,     0,     0,    11,
      12,    24,    25,    26,    27,     0,     0,     0,    13,    14,
      15,   177,    16,    17,     0,    18,     0,    14,    15,    19,
      16,    17,     0,    18,    20,     0,     0,    19,    21,    22,
       0,    23,    50,     0,    11,    12,    21,    22,     0,     0,
      24,    25,    26,    27,     0,    28,     0,     0,    24,    25,
      26,    27,    14,    15,     0,    16,    17,   174,    18,    92,
      93,     0,    19,     0,     0,     0,     0,    50,     0,     0,
       0,    21,    22,    11,    12,     0,     0,     0,     0,     0,
       0,    11,    12,    24,    25,    26,    27,     0,     0,     0,
     129,    14,    15,     0,    16,    17,     0,    18,     0,    14,
      15,    19,    16,    17,     0,    18,    50,     0,     0,    19,
      21,    22,     0,     0,    50,     0,     0,     0,    21,    22,
      11,    12,    24,    25,    26,    27,     0,     0,     0,   123,
      24,    25,    26,    27,     0,     0,     0,   129,    14,    15,
       0,    16,    17,     0,    18,     0,     0,     0,    19,     0,
       0,     0,     0,    50,     0,     0,     0,    21,    22,    11,
      12,     0,     0,     0,     0,     0,     0,    11,    12,    24,
      25,    26,    27,     0,     0,     0,   175,    14,    15,     0,
      16,    17,     0,    18,     0,    14,    15,    19,    16,    17,
       0,    18,    50,     0,     0,    19,    21,    22,     0,     0,
      50,     0,     0,     0,    21,    22,    11,    12,    24,    25,
      26,    27,     0,     0,     0,   222,    24,    25,    26,    27,
       0,     0,     0,   232,    14,    15,     0,    16,    17,     0,
      18,     0,     0,     0,    19,     0,     0,     0,     0,    50,
       0,     0,     0,    21,    22,     0,    11,    12,     0,     0,
       0,     0,     0,     0,     0,    24,    25,    26,    27,     0,
       0,     0,   233,    13,    14,    15,     0,    16,    17,     0,
      18,     0,     0,     0,    19,     0,     0,     0,     0,    20,
       0,    11,    12,    21,    22,     0,    23,     0,     0,     0,
       0,     0,     0,     0,     0,    24,    25,    26,    27,    14,
      15,     0,    16,    17,     0,    18,    92,    93,     0,    19,
       0,     0,     0,     0,    50,     0,     0,     0,    21,    22,
      11,    12,     0,     0,     0,     0,     0,     0,    11,    12,
      24,    25,    26,    27,     0,     0,     0,   156,    14,    15,
       0,    16,    17,     0,    18,     0,    14,    15,    19,    16,
      17,     0,    18,   157,     0,     0,    19,    21,    22,     0,
       0,    60,     0,    11,    12,    21,    22,     0,     0,    24,
      25,    26,    27,     0,     0,     0,     0,    24,    25,    26,
      27,    14,    15,     0,    16,    17,     0,    18,     0,     0,
       0,    19,     0,     0,     0,     0,    50,     0,     0,     0,
      21,    22,   179,     0,   131,   132,   133,   134,   135,   136,
     137,     0,    24,    25,    26,    27,     0,   181,   182,   183,
     179,     0,   131,   132,   133,   134,   135,   136,   137,     0,
       0,   207,     0,   180,     0,   181,   182,   183
};

static const yytype_int16 yycheck[] =
{
       8,    28,    30,    11,   106,    13,    39,    78,    89,    48,
      49,    92,    20,    53,    48,    49,     8,    57,    75,    76,
      77,    13,    48,    49,    51,     8,    48,    49,    20,    87,
      13,   105,    59,    41,    42,    21,    22,    20,    24,    25,
      30,    27,    50,    47,    13,    58,    48,    49,     0,    35,
      87,    20,    60,    87,    66,    94,    64,    90,    66,    67,
      68,    69,    30,    89,   135,    87,    94,    90,    54,    89,
      92,    66,    92,   100,    92,    61,    84,    66,    82,    83,
      93,    66,   156,   157,    92,    66,    72,    89,    48,    49,
      98,    99,    89,   101,    82,    83,   104,   105,    72,    73,
      74,    87,    88,    89,    90,    91,    98,    99,   179,   101,
      66,   119,   120,    66,   216,    98,    99,    89,   101,    48,
      49,   195,   196,    89,   226,   111,   200,    73,   168,    98,
      99,   117,   101,    41,    42,   121,   122,    36,   124,   125,
     126,    30,    49,   197,   198,    94,   154,   155,   156,   157,
      52,    89,    52,    49,   140,    89,    89,    21,    22,   186,
     146,    89,    20,    27,   157,   157,    60,   103,   176,   177,
     224,    35,    93,    -1,   157,   161,   230,    70,    71,    72,
      73,    74,   236,    51,    52,   171,   172,   195,   196,   229,
      54,    -1,   200,    61,    -1,   235,    -1,    61,   238,    -1,
      -1,   187,   188,    46,    47,    48,    49,   193,    72,    -1,
      -1,   219,    55,   221,    -1,    -1,    84,    85,     1,   205,
     206,    -1,    -1,    87,    88,    89,    90,    91,    -1,    -1,
      62,    63,    64,    65,    66,    67,    68,    -1,    -1,    -1,
      -1,   227,   228,    75,    76,    77,    -1,   111,    31,    32,
      33,    34,    -1,   117,    -1,    -1,    -1,   121,   122,    -1,
     124,   125,   126,    -1,    -1,    -1,    -1,    -1,    51,    52,
      -1,    54,    55,    -1,    57,    -1,   140,    -1,    61,    -1,
      -1,    -1,   146,    66,    33,    34,    -1,    70,    71,    62,
      63,    64,    65,    66,    67,    68,    -1,   161,    -1,    82,
      83,    84,    85,    -1,    -1,    -1,    -1,   171,   172,    -1,
      -1,    94,    61,    -1,    -1,     1,    -1,    66,    -1,    -1,
      -1,    70,    71,   187,   188,    -1,    -1,    -1,    -1,   193,
      -1,    -1,    -1,    82,    83,    84,    85,    -1,    -1,    -1,
      -1,   205,   206,    -1,    30,    31,    32,    33,    34,    35,
      -1,    37,    38,    -1,    40,    41,    42,    43,    -1,    -1,
      -1,    -1,    -1,   227,   228,    51,    52,    -1,    54,    55,
      -1,    57,    -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,
      66,     1,    -1,    -1,    70,    71,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    82,    83,    84,    85,
      -1,    87,    88,    -1,    -1,    -1,    -1,    -1,    94,    -1,
      30,    31,    32,    33,    34,    35,    -1,    37,    38,    -1,
      40,    41,    42,    43,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    51,    52,    -1,    54,    55,    -1,    57,    -1,    -1,
      -1,    61,    -1,    -1,    -1,    -1,    66,     1,    -1,    -1,
      70,    71,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    82,    83,    84,    85,    -1,    87,    88,    -1,
      -1,    -1,    -1,    -1,    94,    -1,    30,    31,    32,    33,
      34,    35,    -1,    37,    38,    -1,    40,    41,    42,    43,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    51,    52,    -1,
      54,    55,    -1,    57,    -1,    -1,    -1,    61,    -1,    -1,
      -1,    -1,    66,     1,    -1,    -1,    70,    71,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    82,    83,
      84,    85,    -1,    87,    88,    -1,    -1,    -1,    -1,    -1,
      94,    -1,    30,    31,    32,    33,    34,    35,    -1,    37,
      38,    -1,    40,    41,    42,    43,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    51,    52,    -1,    54,    55,    -1,    57,
      -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,    66,     1,
      -1,    -1,    70,    71,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    82,    83,    84,    85,    -1,    87,
      88,    -1,    -1,    -1,    -1,    -1,    94,    -1,    30,    31,
      32,    33,    34,    35,    -1,    37,    38,    -1,    40,    41,
      42,    43,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    51,
      52,    -1,    54,    55,    -1,    57,    -1,    -1,    -1,    61,
      -1,    -1,    -1,    -1,    66,     1,    -1,    -1,    70,    71,
      -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      82,    83,    84,    85,    -1,    87,    88,    -1,    -1,    -1,
      -1,    -1,    94,    -1,    30,    31,    32,    33,    34,    35,
      -1,    37,    38,    -1,    40,    41,    42,    43,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    51,    52,    -1,    54,    55,
      -1,    57,    -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,
      66,     1,    -1,    -1,    70,    71,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    82,    83,    84,    85,
      -1,    87,    88,    -1,    -1,    -1,    -1,    -1,    94,    -1,
      30,    31,    32,    33,    34,    35,    -1,    37,    38,    -1,
      40,    41,    42,    43,    -1,     1,    -1,    -1,    -1,    -1,
      -1,    51,    52,    -1,    54,    55,    -1,    57,    -1,    -1,
      -1,    61,    -1,    -1,    -1,    -1,    66,    -1,    -1,    -1,
      70,    71,    -1,    -1,    -1,    31,    32,    33,    34,    -1,
      -1,    -1,    82,    83,    84,    85,    -1,    87,     0,     1,
      -1,    -1,    -1,    -1,    94,    51,    52,    -1,    54,    55,
      -1,    57,    -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,
      66,    -1,    -1,    -1,    70,    71,    28,    29,    30,    -1,
      -1,    33,    34,    -1,    -1,    -1,    82,    83,    84,    85,
      -1,    -1,    -1,    89,    -1,    -1,    -1,    -1,    50,    51,
      52,    -1,    54,    55,    -1,    57,    -1,    -1,    -1,    61,
      -1,    -1,    -1,    -1,    66,    -1,    -1,    -1,    70,    71,
      -1,    73,    33,    34,    -1,    -1,    -1,    -1,    -1,    -1,
      82,    83,    84,    85,    -1,    87,    -1,    -1,    -1,    50,
      51,    52,    -1,    54,    55,    -1,    57,    -1,    -1,    -1,
      61,    -1,    -1,    -1,    -1,    66,    -1,    33,    34,    70,
      71,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    82,    83,    84,    85,    51,    52,    -1,    54,    55,
      -1,    57,    -1,    94,    -1,    61,    -1,    -1,    -1,    -1,
      66,    -1,    -1,    -1,    70,    71,    33,    34,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    -1,    82,    83,    84,    85,
      -1,    -1,    -1,    89,    51,    52,    92,    54,    55,    -1,
      57,    -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,    66,
      -1,    -1,    -1,    70,    71,    33,    34,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    82,    83,    84,    85,    -1,
      -1,    -1,    89,    51,    52,    92,    54,    55,    -1,    57,
      -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,    66,    -1,
      -1,    -1,    70,    71,    33,    34,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    82,    83,    84,    85,    -1,    -1,
      -1,    -1,    51,    52,    92,    54,    55,    -1,    57,    -1,
      -1,    -1,    61,    -1,    -1,    -1,    -1,    66,    -1,    -1,
      -1,    70,    71,    33,    34,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    -1,    82,    83,    84,    85,    -1,    -1,    -1,
      -1,    51,    52,    92,    54,    55,    -1,    57,    -1,    -1,
      -1,    61,    -1,    -1,    -1,    -1,    66,    -1,    -1,    -1,
      70,    71,    33,    34,    -1,    -1,    -1,    -1,    -1,    -1,
      -1,    -1,    82,    83,    84,    85,    -1,    -1,    -1,    -1,
      51,    52,    92,    54,    55,    -1,    57,    -1,    -1,    -1,
      61,    -1,    -1,    -1,    -1,    66,    -1,    29,    -1,    70,
      71,    33,    34,    -1,    -1,    -1,    -1,    -1,    -1,    33,
      34,    82,    83,    84,    85,    -1,    -1,    -1,    50,    51,
      52,    92,    54,    55,    -1,    57,    -1,    51,    52,    61,
      54,    55,    -1,    57,    66,    -1,    -1,    61,    70,    71,
      -1,    73,    66,    -1,    33,    34,    70,    71,    -1,    -1,
      82,    83,    84,    85,    -1,    87,    -1,    -1,    82,    83,
      84,    85,    51,    52,    -1,    54,    55,    91,    57,    58,
      59,    -1,    61,    -1,    -1,    -1,    -1,    66,    -1,    -1,
      -1,    70,    71,    33,    34,    -1,    -1,    -1,    -1,    -1,
      -1,    33,    34,    82,    83,    84,    85,    -1,    -1,    -1,
      89,    51,    52,    -1,    54,    55,    -1,    57,    -1,    51,
      52,    61,    54,    55,    -1,    57,    66,    -1,    -1,    61,
      70,    71,    -1,    -1,    66,    -1,    -1,    -1,    70,    71,
      33,    34,    82,    83,    84,    85,    -1,    -1,    -1,    89,
      82,    83,    84,    85,    -1,    -1,    -1,    89,    51,    52,
      -1,    54,    55,    -1,    57,    -1,    -1,    -1,    61,    -1,
      -1,    -1,    -1,    66,    -1,    -1,    -1,    70,    71,    33,
      34,    -1,    -1,    -1,    -1,    -1,    -1,    33,    34,    82,
      83,    84,    85,    -1,    -1,    -1,    89,    51,    52,    -1,
      54,    55,    -1,    57,    -1,    51,    52,    61,    54,    55,
      -1,    57,    66,    -1,    -1,    61,    70,    71,    -1,    -1,
      66,    -1,    -1,    -1,    70,    71,    33,    34,    82,    83,
      84,    85,    -1,    -1,    -1,    89,    82,    83,    84,    85,
      -1,    -1,    -1,    89,    51,    52,    -1,    54,    55,    -1,
      57,    -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,    66,
      -1,    -1,    -1,    70,    71,    -1,    33,    34,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    82,    83,    84,    85,    -1,
      -1,    -1,    89,    50,    51,    52,    -1,    54,    55,    -1,
      57,    -1,    -1,    -1,    61,    -1,    -1,    -1,    -1,    66,
      -1,    33,    34,    70,    71,    -1,    73,    -1,    -1,    -1,
      -1,    -1,    -1,    -1,    -1,    82,    83,    84,    85,    51,
      52,    -1,    54,    55,    -1,    57,    58,    59,    -1,    61,
      -1,    -1,    -1,    -1,    66,    -1,    -1,    -1,    70,    71,
      33,    34,    -1,    -1,    -1,    -1,    -1,    -1,    33,    34,
      82,    83,    84,    85,    -1,    -1,    -1,    50,    51,    52,
      -1,    54,    55,    -1,    57,    -1,    51,    52,    61,    54,
      55,    -1,    57,    66,    -1,    -1,    61,    70,    71,    -1,
      -1,    66,    -1,    33,    34,    70,    71,    -1,    -1,    82,
      83,    84,    85,    -1,    -1,    -1,    -1,    82,    83,    84,
      85,    51,    52,    -1,    54,    55,    -1,    57,    -1,    -1,
      -1,    61,    -1,    -1,    -1,    -1,    66,    -1,    -1,    -1,
      70,    71,    60,    -1,    62,    63,    64,    65,    66,    67,
      68,    -1,    82,    83,    84,    85,    -1,    75,    76,    77,
      60,    -1,    62,    63,    64,    65,    66,    67,    68,    -1,
      -1,    89,    -1,    73,    -1,    75,    76,    77
};

/* YYSTOS[STATE-NUM] -- The symbol kind of the accessing symbol of
   state STATE-NUM.  */
static const yytype_int8 yystos[] =
{
       0,     1,    28,    96,    97,    87,     0,    30,   111,   123,
      29,    33,    34,    50,    51,    52,    54,    55,    57,    61,
      66,    70,    71,    73,    82,    83,    84,    85,    87,    98,
     100,   103,   105,   106,   107,   108,   110,   112,   116,   119,
       1,    31,    32,    35,    37,    38,    40,    41,    42,    43,
      66,    87,    88,   104,   108,   121,   122,   124,   125,    87,
      66,   108,   113,   114,    66,   112,    90,    66,    66,    66,
     100,   105,   108,   112,   119,   106,   107,   107,   117,   106,
     106,   107,   123,    30,    47,    82,    83,    70,    71,    72,
      73,    74,    58,    59,   107,    30,    94,   120,    48,    49,
      87,    92,   113,   113,    66,    66,    66,   120,   120,   120,
     120,   108,   123,   122,   120,   122,   123,   108,   114,    92,
      92,   108,   108,    89,   108,   108,   108,    89,    89,    89,
      89,    62,    63,    64,    65,    66,    67,    68,   118,    88,
     108,   107,   107,   107,   107,   107,   108,   116,   112,   112,
     123,   112,    58,    93,   115,   115,    50,    66,    99,   101,
     105,   108,   119,   101,    52,   121,    88,    36,   102,    88,
      89,   108,   108,    92,    91,    89,    92,    92,   118,    60,
      73,    75,    76,    77,   118,    88,    87,   108,   108,   101,
      99,   101,   105,   108,   119,    48,    49,    89,    89,    39,
      94,    30,   109,   122,    52,   108,   108,    89,   118,   123,
      89,   101,   101,   109,   109,    52,    94,   101,    89,    92,
      89,    92,    89,    88,    89,   121,    94,   108,   108,   109,
      89,   121,    89,    89,   122,   109,    89,   122,   109,   122
};

/* YYR1[RULE-NUM] -- Symbol kind of the left-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr1[] =
{
       0,    95,    96,    96,    97,    97,    97,    98,    98,    98,
      99,    99,    99,    99,   100,   100,   100,   100,   101,   101,
     101,   101,   102,   103,   103,   104,   105,   105,   106,   106,
     106,   106,   106,   107,   107,   107,   107,   107,   107,   107,
     107,   107,   107,   107,   107,   107,   107,   107,   107,   107,
     107,   107,   107,   107,   107,   108,   108,   108,   109,   109,
     110,   110,   110,   110,   110,   111,   111,   111,   112,   112,
     112,   112,   112,   113,   113,   114,   114,   114,   115,   115,
     117,   116,   118,   118,   118,   118,   118,   118,   118,   118,
     118,   118,   118,   118,   119,   119,   120,   120,   121,   121,
     121,   121,   121,   121,   121,   122,   122,   122,   122,   122,
     122,   122,   122,   122,   122,   123,   123,   124,   125,   125,
     125
};

/* YYR2[RULE-NUM] -- Number of symbols on the right-hand side of rule RULE-NUM.  */
static const yytype_int8 yyr2[] =
{
       0,     2,     3,     1,     4,     2,     0,     4,     2,     0,
       3,     3,     2,     3,     3,     3,     2,     3,     1,     1,
       1,     1,     2,     1,     2,     5,     3,     3,     1,     1,
       1,     4,     1,     1,     1,     3,     4,     2,     8,     6,
       8,     6,     6,     3,     3,     3,     3,     3,     3,     2,
       2,     2,     2,     2,     2,     1,     2,     3,     1,     0,
       1,     4,     3,     6,     3,     3,     0,     2,     1,     1,
       1,     1,     1,     1,     1,     3,     3,     3,     1,     1,
       0,     4,     1,     1,     1,     1,     1,     1,     3,     2,
       2,     2,     2,     3,     3,     3,     1,     1,     4,     2,
       4,     2,     1,     0,     1,     2,     2,     4,     2,     1,
       2,     2,     2,     2,     3,     2,     0,     5,    10,     9,
       8
};


enum { YYENOMEM = -2 };

#define yyerrok         (yyerrstatus = 0)
#define yyclearin       (yychar = YYEMPTY)

#define YYACCEPT        goto yyacceptlab
#define YYABORT         goto yyabortlab
#define YYERROR         goto yyerrorlab
#define YYNOMEM         goto yyexhaustedlab


#define YYRECOVERING()  (!!yyerrstatus)

#define YYBACKUP(Token, Value)                                    \
  do                                                              \
    if (yychar == YYEMPTY)                                        \
      {                                                           \
        yychar = (Token);                                         \
        yylval = (Value);                                         \
        YYPOPSTACK (yylen);                                       \
        yystate = *yyssp;                                         \
        goto yybackup;                                            \
      }                                                           \
    else                                                          \
      {                                                           \
        yyerror (YY_("syntax error: cannot back up")); \
        YYERROR;                                                  \
      }                                                           \
  while (0)

/* Backward compatibility with an undocumented macro.
   Use YYerror or YYUNDEF. */
#define YYERRCODE YYUNDEF


/* Enable debugging if requested.  */
#if YYDEBUG

# ifndef YYFPRINTF
#  include <stdio.h> /* INFRINGES ON USER NAME SPACE */
#  define YYFPRINTF fprintf
# endif

# define YYDPRINTF(Args)                        \
do {                                            \
  if (yydebug)                                  \
    YYFPRINTF Args;                             \
} while (0)




# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)                    \
do {                                                                      \
  if (yydebug)                                                            \
    {                                                                     \
      YYFPRINTF (stderr, "%s ", Title);                                   \
      yy_symbol_print (stderr,                                            \
                  Kind, Value); \
      YYFPRINTF (stderr, "\n");                                           \
    }                                                                     \
} while (0)


/*-----------------------------------.
| Print this symbol's value on YYO.  |
`-----------------------------------*/

static void
yy_symbol_value_print (FILE *yyo,
                       yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep)
{
  FILE *yyoutput = yyo;
  YY_USE (yyoutput);
  if (!yyvaluep)
    return;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/*---------------------------.
| Print this symbol on YYO.  |
`---------------------------*/

static void
yy_symbol_print (FILE *yyo,
                 yysymbol_kind_t yykind, YYSTYPE const * const yyvaluep)
{
  YYFPRINTF (yyo, "%s %s (",
             yykind < YYNTOKENS ? "token" : "nterm", yysymbol_name (yykind));

  yy_symbol_value_print (yyo, yykind, yyvaluep);
  YYFPRINTF (yyo, ")");
}

/*------------------------------------------------------------------.
| yy_stack_print -- Print the state stack from its BOTTOM up to its |
| TOP (included).                                                   |
`------------------------------------------------------------------*/

static void
yy_stack_print (yy_state_t *yybottom, yy_state_t *yytop)
{
  YYFPRINTF (stderr, "Stack now");
  for (; yybottom <= yytop; yybottom++)
    {
      int yybot = *yybottom;
      YYFPRINTF (stderr, " %d", yybot);
    }
  YYFPRINTF (stderr, "\n");
}

# define YY_STACK_PRINT(Bottom, Top)                            \
do {                                                            \
  if (yydebug)                                                  \
    yy_stack_print ((Bottom), (Top));                           \
} while (0)


/*------------------------------------------------.
| Report that the YYRULE is going to be reduced.  |
`------------------------------------------------*/

static void
yy_reduce_print (yy_state_t *yyssp, YYSTYPE *yyvsp,
                 int yyrule)
{
  int yylno = yyrline[yyrule];
  int yynrhs = yyr2[yyrule];
  int yyi;
  YYFPRINTF (stderr, "Reducing stack by rule %d (line %d):\n",
             yyrule - 1, yylno);
  /* The symbols being reduced.  */
  for (yyi = 0; yyi < yynrhs; yyi++)
    {
      YYFPRINTF (stderr, "   $%d = ", yyi + 1);
      yy_symbol_print (stderr,
                       YY_ACCESSING_SYMBOL (+yyssp[yyi + 1 - yynrhs]),
                       &yyvsp[(yyi + 1) - (yynrhs)]);
      YYFPRINTF (stderr, "\n");
    }
}

# define YY_REDUCE_PRINT(Rule)          \
do {                                    \
  if (yydebug)                          \
    yy_reduce_print (yyssp, yyvsp, Rule); \
} while (0)

/* Nonzero means print parse trace.  It is left uninitialized so that
   multiple parsers can coexist.  */
int yydebug;
#else /* !YYDEBUG */
# define YYDPRINTF(Args) ((void) 0)
# define YY_SYMBOL_PRINT(Title, Kind, Value, Location)
# define YY_STACK_PRINT(Bottom, Top)
# define YY_REDUCE_PRINT(Rule)
#endif /* !YYDEBUG */


/* YYINITDEPTH -- initial size of the parser's stacks.  */
#ifndef YYINITDEPTH
# define YYINITDEPTH 200
#endif

/* YYMAXDEPTH -- maximum size the stacks can grow to (effective only
   if the built-in stack extension method is used).

   Do not make this value too large; the results are undefined if
   YYSTACK_ALLOC_MAXIMUM < YYSTACK_BYTES (YYMAXDEPTH)
   evaluated with infinite-precision integer arithmetic.  */

#ifndef YYMAXDEPTH
# define YYMAXDEPTH 10000
#endif






/*-----------------------------------------------.
| Release the memory associated to this symbol.  |
`-----------------------------------------------*/

static void
yydestruct (const char *yymsg,
            yysymbol_kind_t yykind, YYSTYPE *yyvaluep)
{
  YY_USE (yyvaluep);
  if (!yymsg)
    yymsg = "Deleting";
  YY_SYMBOL_PRINT (yymsg, yykind, yyvaluep, yylocationp);

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  YY_USE (yykind);
  YY_IGNORE_MAYBE_UNINITIALIZED_END
}


/* Lookahead token kind.  */
int yychar;

/* The semantic value of the lookahead symbol.  */
YYSTYPE yylval;
/* Number of syntax errors so far.  */
int yynerrs;




/*----------.
| yyparse.  |
`----------*/

int
yyparse (void)
{
    yy_state_fast_t yystate = 0;
    /* Number of tokens to shift before error messages enabled.  */
    int yyerrstatus = 0;

    /* Refer to the stacks through separate pointers, to allow yyoverflow
       to reallocate them elsewhere.  */

    /* Their size.  */
    YYPTRDIFF_T yystacksize = YYINITDEPTH;

    /* The state stack: array, bottom, top.  */
    yy_state_t yyssa[YYINITDEPTH];
    yy_state_t *yyss = yyssa;
    yy_state_t *yyssp = yyss;

    /* The semantic value stack: array, bottom, top.  */
    YYSTYPE yyvsa[YYINITDEPTH];
    YYSTYPE *yyvs = yyvsa;
    YYSTYPE *yyvsp = yyvs;

  int yyn;
  /* The return value of yyparse.  */
  int yyresult;
  /* Lookahead symbol kind.  */
  yysymbol_kind_t yytoken = YYSYMBOL_YYEMPTY;
  /* The variables used to return semantic value and location from the
     action routines.  */
  YYSTYPE yyval;



#define YYPOPSTACK(N)   (yyvsp -= (N), yyssp -= (N))

  /* The number of symbols on the RHS of the reduced rule.
     Keep to zero when no symbol should be popped.  */
  int yylen = 0;

  YYDPRINTF ((stderr, "Starting parse\n"));

  yychar = YYEMPTY; /* Cause a token to be read.  */

  goto yysetstate;


/*------------------------------------------------------------.
| yynewstate -- push a new state, which is found in yystate.  |
`------------------------------------------------------------*/
yynewstate:
  /* In all cases, when you get here, the value and location stacks
     have just been pushed.  So pushing a state here evens the stacks.  */
  yyssp++;


/*--------------------------------------------------------------------.
| yysetstate -- set current state (the top of the stack) to yystate.  |
`--------------------------------------------------------------------*/
yysetstate:
  YYDPRINTF ((stderr, "Entering state %d\n", yystate));
  YY_ASSERT (0 <= yystate && yystate < YYNSTATES);
  YY_IGNORE_USELESS_CAST_BEGIN
  *yyssp = YY_CAST (yy_state_t, yystate);
  YY_IGNORE_USELESS_CAST_END
  YY_STACK_PRINT (yyss, yyssp);

  if (yyss + yystacksize - 1 <= yyssp)
#if !defined yyoverflow && !defined YYSTACK_RELOCATE
    YYNOMEM;
#else
    {
      /* Get the current used size of the three stacks, in elements.  */
      YYPTRDIFF_T yysize = yyssp - yyss + 1;

# if defined yyoverflow
      {
        /* Give user a chance to reallocate the stack.  Use copies of
           these so that the &'s don't force the real ones into
           memory.  */
        yy_state_t *yyss1 = yyss;
        YYSTYPE *yyvs1 = yyvs;

        /* Each stack pointer address is followed by the size of the
           data in use in that stack, in bytes.  This used to be a
           conditional around just the two extra args, but that might
           be undefined if yyoverflow is a macro.  */
        yyoverflow (YY_("memory exhausted"),
                    &yyss1, yysize * YYSIZEOF (*yyssp),
                    &yyvs1, yysize * YYSIZEOF (*yyvsp),
                    &yystacksize);
        yyss = yyss1;
        yyvs = yyvs1;
      }
# else /* defined YYSTACK_RELOCATE */
      /* Extend the stack our own way.  */
      if (YYMAXDEPTH <= yystacksize)
        YYNOMEM;
      yystacksize *= 2;
      if (YYMAXDEPTH < yystacksize)
        yystacksize = YYMAXDEPTH;

      {
        yy_state_t *yyss1 = yyss;
        union yyalloc *yyptr =
          YY_CAST (union yyalloc *,
                   YYSTACK_ALLOC (YY_CAST (YYSIZE_T, YYSTACK_BYTES (yystacksize))));
        if (! yyptr)
          YYNOMEM;
        YYSTACK_RELOCATE (yyss_alloc, yyss);
        YYSTACK_RELOCATE (yyvs_alloc, yyvs);
#  undef YYSTACK_RELOCATE
        if (yyss1 != yyssa)
          YYSTACK_FREE (yyss1);
      }
# endif

      yyssp = yyss + yysize - 1;
      yyvsp = yyvs + yysize - 1;

      YY_IGNORE_USELESS_CAST_BEGIN
      YYDPRINTF ((stderr, "Stack size increased to %ld\n",
                  YY_CAST (long, yystacksize)));
      YY_IGNORE_USELESS_CAST_END

      if (yyss + yystacksize - 1 <= yyssp)
        YYABORT;
    }
#endif /* !defined yyoverflow && !defined YYSTACK_RELOCATE */


  if (yystate == YYFINAL)
    YYACCEPT;

  goto yybackup;


/*-----------.
| yybackup.  |
`-----------*/
yybackup:
  /* Do appropriate processing given the current state.  Read a
     lookahead token if we need one and don't already have one.  */

  /* First try to decide what to do without reference to lookahead token.  */
  yyn = yypact[yystate];
  if (yypact_value_is_default (yyn))
    goto yydefault;

  /* Not known => get a lookahead token if don't already have one.  */

  /* YYCHAR is either empty, or end-of-input, or a valid lookahead.  */
  if (yychar == YYEMPTY)
    {
      YYDPRINTF ((stderr, "Reading a token\n"));
      yychar = yylex ();
    }

  if (yychar <= YYEOF)
    {
      yychar = YYEOF;
      yytoken = YYSYMBOL_YYEOF;
      YYDPRINTF ((stderr, "Now at end of input.\n"));
    }
  else if (yychar == YYerror)
    {
      /* The scanner already issued an error message, process directly
         to error recovery.  But do not keep the error token as
         lookahead, it is too special and may lead us to an endless
         loop in error recovery. */
      yychar = YYUNDEF;
      yytoken = YYSYMBOL_YYerror;
      goto yyerrlab1;
    }
  else
    {
      yytoken = YYTRANSLATE (yychar);
      YY_SYMBOL_PRINT ("Next token is", yytoken, &yylval, &yylloc);
    }

  /* If the proper action on seeing token YYTOKEN is to reduce or to
     detect an error, take that action.  */
  yyn += yytoken;
  if (yyn < 0 || YYLAST < yyn || yycheck[yyn] != yytoken)
    goto yydefault;
  yyn = yytable[yyn];
  if (yyn <= 0)
    {
      if (yytable_value_is_error (yyn))
        goto yyerrlab;
      yyn = -yyn;
      goto yyreduce;
    }

  /* Count tokens shifted since error; after three, turn off error
     status.  */
  if (yyerrstatus)
    yyerrstatus--;

  /* Shift the lookahead token.  */
  YY_SYMBOL_PRINT ("Shifting", yytoken, &yylval, &yylloc);
  yystate = yyn;
  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END

  /* Discard the shifted token.  */
  yychar = YYEMPTY;
  goto yynewstate;


/*-----------------------------------------------------------.
| yydefault -- do the default action for the current state.  |
`-----------------------------------------------------------*/
yydefault:
  yyn = yydefact[yystate];
  if (yyn == 0)
    goto yyerrlab;
  goto yyreduce;


/*-----------------------------.
| yyreduce -- do a reduction.  |
`-----------------------------*/
yyreduce:
  /* yyn is the number of a rule to reduce with.  */
  yylen = yyr2[yyn];

  /* If YYLEN is nonzero, implement the default value of the action:
     '$$ = $1'.

     Otherwise, the following line sets YYVAL to garbage.
     This behavior is undocumented and Bison
     users should not rely upon it.  Assigning to YYVAL
     unconditionally makes the parser a bit smaller, and it avoids a
     GCC warning that YYVAL may be used uninitialized.  */
  yyval = yyvsp[1-yylen];


  YY_REDUCE_PRINT (yyn);
  switch (yyn)
    {
  case 2: /* program: begin pa_stats end  */
#line 41 "cmd/awk/awk.g.y"
                                { if (errorflag==0) winner = stat3(PROGRAM, yyvsp[-2], yyvsp[-1], yyvsp[0]); }
#line 1819 "y.tab.c"
    break;

  case 3: /* program: error  */
#line 42 "cmd/awk/awk.g.y"
                                { yyclearin; yyerror("bailing out"); }
#line 1825 "y.tab.c"
    break;

  case 4: /* begin: XBEGIN '{' stat_list '}'  */
#line 46 "cmd/awk/awk.g.y"
                                        { PUTS("XBEGIN list"); yyval = yyvsp[-1]; }
#line 1831 "y.tab.c"
    break;

  case 6: /* begin: %empty  */
#line 48 "cmd/awk/awk.g.y"
                { PUTS("empty XBEGIN"); yyval = nullstat; }
#line 1837 "y.tab.c"
    break;

  case 7: /* end: XEND '{' stat_list '}'  */
#line 52 "cmd/awk/awk.g.y"
                                        { PUTS("XEND list"); yyval = yyvsp[-1]; }
#line 1843 "y.tab.c"
    break;

  case 9: /* end: %empty  */
#line 54 "cmd/awk/awk.g.y"
                { PUTS("empty END"); yyval = nullstat; }
#line 1849 "y.tab.c"
    break;

  case 10: /* compound_conditional: conditional BOR conditional  */
#line 58 "cmd/awk/awk.g.y"
                                        { PUTS("cond||cond"); yyval = op2(BOR, yyvsp[-2], yyvsp[0]); }
#line 1855 "y.tab.c"
    break;

  case 11: /* compound_conditional: conditional AND conditional  */
#line 59 "cmd/awk/awk.g.y"
                                        { PUTS("cond&&cond"); yyval = op2(AND, yyvsp[-2], yyvsp[0]); }
#line 1861 "y.tab.c"
    break;

  case 12: /* compound_conditional: NOT conditional  */
#line 60 "cmd/awk/awk.g.y"
                                        { PUTS("!cond"); yyval = op1(NOT, yyvsp[0]); }
#line 1867 "y.tab.c"
    break;

  case 13: /* compound_conditional: '(' compound_conditional ')'  */
#line 61 "cmd/awk/awk.g.y"
                                        { yyval = yyvsp[-1]; }
#line 1873 "y.tab.c"
    break;

  case 14: /* compound_pattern: pattern BOR pattern  */
#line 65 "cmd/awk/awk.g.y"
                                { PUTS("pat||pat"); yyval = op2(BOR, yyvsp[-2], yyvsp[0]); }
#line 1879 "y.tab.c"
    break;

  case 15: /* compound_pattern: pattern AND pattern  */
#line 66 "cmd/awk/awk.g.y"
                                { PUTS("pat&&pat"); yyval = op2(AND, yyvsp[-2], yyvsp[0]); }
#line 1885 "y.tab.c"
    break;

  case 16: /* compound_pattern: NOT pattern  */
#line 67 "cmd/awk/awk.g.y"
                                { PUTS("!pat"); yyval = op1(NOT, yyvsp[0]); }
#line 1891 "y.tab.c"
    break;

  case 17: /* compound_pattern: '(' compound_pattern ')'  */
#line 68 "cmd/awk/awk.g.y"
                                        { yyval = yyvsp[-1]; }
#line 1897 "y.tab.c"
    break;

  case 18: /* conditional: expr  */
#line 72 "cmd/awk/awk.g.y"
                { PUTS("expr"); yyval = op2(NE, yyvsp[0], valtonode(lookup("0", symtab), CCON)); }
#line 1903 "y.tab.c"
    break;

  case 19: /* conditional: rel_expr  */
#line 73 "cmd/awk/awk.g.y"
                                { PUTS("relexpr"); }
#line 1909 "y.tab.c"
    break;

  case 20: /* conditional: lex_expr  */
#line 74 "cmd/awk/awk.g.y"
                                { PUTS("lexexpr"); }
#line 1915 "y.tab.c"
    break;

  case 21: /* conditional: compound_conditional  */
#line 75 "cmd/awk/awk.g.y"
                                { PUTS("compcond"); }
#line 1921 "y.tab.c"
    break;

  case 22: /* else: ELSE optNL  */
#line 79 "cmd/awk/awk.g.y"
                        { PUTS("else"); }
#line 1927 "y.tab.c"
    break;

  case 23: /* field: FIELD  */
#line 83 "cmd/awk/awk.g.y"
                        { PUTS("field"); yyval = valtonode(yyvsp[0], CFLD); }
#line 1933 "y.tab.c"
    break;

  case 24: /* field: INDIRECT term  */
#line 84 "cmd/awk/awk.g.y"
                        { PUTS("ind field"); yyval = op1(INDIRECT, yyvsp[0]); }
#line 1939 "y.tab.c"
    break;

  case 25: /* if: IF '(' conditional ')' optNL  */
#line 88 "cmd/awk/awk.g.y"
                                        { PUTS("if(cond)"); yyval = yyvsp[-2]; }
#line 1945 "y.tab.c"
    break;

  case 26: /* lex_expr: expr MATCHOP regular_expr  */
#line 92 "cmd/awk/awk.g.y"
                                        { PUTS("expr~re"); yyval = op2(yyvsp[-1], yyvsp[-2], makedfa(yyvsp[0])); }
#line 1951 "y.tab.c"
    break;

  case 27: /* lex_expr: '(' lex_expr ')'  */
#line 93 "cmd/awk/awk.g.y"
                                { PUTS("(lex_expr)"); yyval = yyvsp[-1]; }
#line 1957 "y.tab.c"
    break;

  case 28: /* var: NUMBER  */
#line 97 "cmd/awk/awk.g.y"
                        {PUTS("number"); yyval = valtonode(yyvsp[0], CCON); }
#line 1963 "y.tab.c"
    break;

  case 29: /* var: STRING  */
#line 98 "cmd/awk/awk.g.y"
                        { PUTS("string"); yyval = valtonode(yyvsp[0], CCON); }
#line 1969 "y.tab.c"
    break;

  case 30: /* var: VAR  */
#line 99 "cmd/awk/awk.g.y"
                        { PUTS("var"); yyval = valtonode(yyvsp[0], CVAR); }
#line 1975 "y.tab.c"
    break;

  case 31: /* var: VAR '[' expr ']'  */
#line 100 "cmd/awk/awk.g.y"
                                { PUTS("array[]"); yyval = op2(ARRAY, yyvsp[-3], yyvsp[-1]); }
#line 1981 "y.tab.c"
    break;

  case 34: /* term: FNCN  */
#line 105 "cmd/awk/awk.g.y"
                        { PUTS("func");
			yyval = op2(FNCN, yyvsp[0], valtonode(lookup("$record", symtab), CFLD));
			}
#line 1989 "y.tab.c"
    break;

  case 35: /* term: FNCN '(' ')'  */
#line 108 "cmd/awk/awk.g.y"
                        { PUTS("func()"); 
			yyval = op2(FNCN, yyvsp[-2], valtonode(lookup("$record", symtab), CFLD));
			}
#line 1997 "y.tab.c"
    break;

  case 36: /* term: FNCN '(' expr ')'  */
#line 111 "cmd/awk/awk.g.y"
                                { PUTS("func(expr)"); yyval = op2(FNCN, yyvsp[-3], yyvsp[-1]); }
#line 2003 "y.tab.c"
    break;

  case 37: /* term: SPRINTF print_list  */
#line 112 "cmd/awk/awk.g.y"
                                { PUTS("sprintf"); yyval = op1(yyvsp[-1], yyvsp[0]); }
#line 2009 "y.tab.c"
    break;

  case 38: /* term: SUBSTR '(' expr ',' expr ',' expr ')'  */
#line 114 "cmd/awk/awk.g.y"
                        { PUTS("substr(e,e,e)"); yyval = op3(SUBSTR, yyvsp[-5], yyvsp[-3], yyvsp[-1]); }
#line 2015 "y.tab.c"
    break;

  case 39: /* term: SUBSTR '(' expr ',' expr ')'  */
#line 116 "cmd/awk/awk.g.y"
                        { PUTS("substr(e,e,e)"); yyval = op3(SUBSTR, yyvsp[-3], yyvsp[-1], nullstat); }
#line 2021 "y.tab.c"
    break;

  case 40: /* term: SPLIT '(' expr ',' VAR ',' expr ')'  */
#line 118 "cmd/awk/awk.g.y"
                        { PUTS("split(e,e,e)"); yyval = op3(SPLIT, yyvsp[-5], yyvsp[-3], yyvsp[-1]); }
#line 2027 "y.tab.c"
    break;

  case 41: /* term: SPLIT '(' expr ',' VAR ')'  */
#line 120 "cmd/awk/awk.g.y"
                        { PUTS("split(e,e,e)"); yyval = op3(SPLIT, yyvsp[-3], yyvsp[-1], nullstat); }
#line 2033 "y.tab.c"
    break;

  case 42: /* term: INDEX '(' expr ',' expr ')'  */
#line 122 "cmd/awk/awk.g.y"
                        { PUTS("index(e,e)"); yyval = op2(INDEX, yyvsp[-3], yyvsp[-1]); }
#line 2039 "y.tab.c"
    break;

  case 43: /* term: '(' expr ')'  */
#line 123 "cmd/awk/awk.g.y"
                                        {PUTS("(expr)");  yyval = yyvsp[-1]; }
#line 2045 "y.tab.c"
    break;

  case 44: /* term: term '+' term  */
#line 124 "cmd/awk/awk.g.y"
                                        { PUTS("t+t"); yyval = op2(ADD, yyvsp[-2], yyvsp[0]); }
#line 2051 "y.tab.c"
    break;

  case 45: /* term: term '-' term  */
#line 125 "cmd/awk/awk.g.y"
                                        { PUTS("t-t"); yyval = op2(MINUS, yyvsp[-2], yyvsp[0]); }
#line 2057 "y.tab.c"
    break;

  case 46: /* term: term '*' term  */
#line 126 "cmd/awk/awk.g.y"
                                        { PUTS("t*t"); yyval = op2(MULT, yyvsp[-2], yyvsp[0]); }
#line 2063 "y.tab.c"
    break;

  case 47: /* term: term '/' term  */
#line 127 "cmd/awk/awk.g.y"
                                        { PUTS("t/t"); yyval = op2(DIVIDE, yyvsp[-2], yyvsp[0]); }
#line 2069 "y.tab.c"
    break;

  case 48: /* term: term '%' term  */
#line 128 "cmd/awk/awk.g.y"
                                        { PUTS("t%t"); yyval = op2(MOD, yyvsp[-2], yyvsp[0]); }
#line 2075 "y.tab.c"
    break;

  case 49: /* term: '-' term  */
#line 129 "cmd/awk/awk.g.y"
                                        { PUTS("-term"); yyval = op1(UMINUS, yyvsp[0]); }
#line 2081 "y.tab.c"
    break;

  case 50: /* term: '+' term  */
#line 130 "cmd/awk/awk.g.y"
                                        { PUTS("+term"); yyval = yyvsp[0]; }
#line 2087 "y.tab.c"
    break;

  case 51: /* term: INCR var  */
#line 131 "cmd/awk/awk.g.y"
                        { PUTS("++var"); yyval = op1(PREINCR, yyvsp[0]); }
#line 2093 "y.tab.c"
    break;

  case 52: /* term: DECR var  */
#line 132 "cmd/awk/awk.g.y"
                        { PUTS("--var"); yyval = op1(PREDECR, yyvsp[0]); }
#line 2099 "y.tab.c"
    break;

  case 53: /* term: var INCR  */
#line 133 "cmd/awk/awk.g.y"
                        { PUTS("var++"); yyval= op1(POSTINCR, yyvsp[-1]); }
#line 2105 "y.tab.c"
    break;

  case 54: /* term: var DECR  */
#line 134 "cmd/awk/awk.g.y"
                        { PUTS("var--"); yyval= op1(POSTDECR, yyvsp[-1]); }
#line 2111 "y.tab.c"
    break;

  case 55: /* expr: term  */
#line 138 "cmd/awk/awk.g.y"
                        { PUTS("term"); }
#line 2117 "y.tab.c"
    break;

  case 56: /* expr: expr term  */
#line 139 "cmd/awk/awk.g.y"
                        { PUTS("expr term"); yyval = op2(CAT, yyvsp[-1], yyvsp[0]); }
#line 2123 "y.tab.c"
    break;

  case 57: /* expr: var ASGNOP expr  */
#line 140 "cmd/awk/awk.g.y"
                                { PUTS("var=expr"); yyval = stat2(yyvsp[-1], yyvsp[-2], yyvsp[0]); }
#line 2129 "y.tab.c"
    break;

  case 60: /* pa_stat: pattern  */
#line 149 "cmd/awk/awk.g.y"
                        { PUTS("pattern"); yyval = stat2(PASTAT, yyvsp[0], genprint()); }
#line 2135 "y.tab.c"
    break;

  case 61: /* pa_stat: pattern '{' stat_list '}'  */
#line 150 "cmd/awk/awk.g.y"
                                        { PUTS("pattern {...}"); yyval = stat2(PASTAT, yyvsp[-3], yyvsp[-1]); }
#line 2141 "y.tab.c"
    break;

  case 62: /* pa_stat: pattern ',' pattern  */
#line 151 "cmd/awk/awk.g.y"
                                        { PUTS("srch,srch"); yyval = pa2stat(yyvsp[-2], yyvsp[0], genprint()); }
#line 2147 "y.tab.c"
    break;

  case 63: /* pa_stat: pattern ',' pattern '{' stat_list '}'  */
#line 153 "cmd/awk/awk.g.y"
                                        { PUTS("srch, srch {...}"); yyval = pa2stat(yyvsp[-5], yyvsp[-3], yyvsp[-1]); }
#line 2153 "y.tab.c"
    break;

  case 64: /* pa_stat: '{' stat_list '}'  */
#line 154 "cmd/awk/awk.g.y"
                                { PUTS("null pattern {...}"); yyval = stat2(PASTAT, nullstat, yyvsp[-1]); }
#line 2159 "y.tab.c"
    break;

  case 65: /* pa_stats: pa_stats pa_stat st  */
#line 158 "cmd/awk/awk.g.y"
                                { PUTS("pa_stats pa_stat"); yyval = linkum(yyvsp[-2], yyvsp[-1]); }
#line 2165 "y.tab.c"
    break;

  case 66: /* pa_stats: %empty  */
#line 159 "cmd/awk/awk.g.y"
                { PUTS("null pa_stat"); yyval = nullstat; }
#line 2171 "y.tab.c"
    break;

  case 67: /* pa_stats: pa_stats pa_stat  */
#line 160 "cmd/awk/awk.g.y"
                                {PUTS("pa_stats pa_stat"); yyval = linkum(yyvsp[-1], yyvsp[0]); }
#line 2177 "y.tab.c"
    break;

  case 68: /* pattern: regular_expr  */
#line 164 "cmd/awk/awk.g.y"
                        { PUTS("regex");
		yyval = op2(MATCH, valtonode(lookup("$record", symtab), CFLD), makedfa(yyvsp[0]));
		}
#line 2185 "y.tab.c"
    break;

  case 69: /* pattern: expr  */
#line 167 "cmd/awk/awk.g.y"
                { PUTS("expr");
		yyval = op2(NE, yyvsp[0], valtonode(lookup("0", symtab), CCON));
		}
#line 2193 "y.tab.c"
    break;

  case 70: /* pattern: rel_expr  */
#line 170 "cmd/awk/awk.g.y"
                        { PUTS("relexpr"); }
#line 2199 "y.tab.c"
    break;

  case 71: /* pattern: lex_expr  */
#line 171 "cmd/awk/awk.g.y"
                        { PUTS("lexexpr"); }
#line 2205 "y.tab.c"
    break;

  case 72: /* pattern: compound_pattern  */
#line 172 "cmd/awk/awk.g.y"
                                { PUTS("comp pat"); }
#line 2211 "y.tab.c"
    break;

  case 73: /* print_list: expr  */
#line 176 "cmd/awk/awk.g.y"
                { PUTS("expr"); }
#line 2217 "y.tab.c"
    break;

  case 74: /* print_list: pe_list  */
#line 177 "cmd/awk/awk.g.y"
                        { PUTS("pe_list"); }
#line 2223 "y.tab.c"
    break;

  case 75: /* pe_list: expr ',' expr  */
#line 181 "cmd/awk/awk.g.y"
                        {yyval = linkum(yyvsp[-2], yyvsp[0]); }
#line 2229 "y.tab.c"
    break;

  case 76: /* pe_list: pe_list ',' expr  */
#line 182 "cmd/awk/awk.g.y"
                                {yyval = linkum(yyvsp[-2], yyvsp[0]); }
#line 2235 "y.tab.c"
    break;

  case 77: /* pe_list: '(' pe_list ')'  */
#line 183 "cmd/awk/awk.g.y"
                                        {yyval = yyvsp[-1]; }
#line 2241 "y.tab.c"
    break;

  case 80: /* $@1: %empty  */
#line 192 "cmd/awk/awk.g.y"
                { startreg(); }
#line 2247 "y.tab.c"
    break;

  case 81: /* regular_expr: '/' $@1 r '/'  */
#line 194 "cmd/awk/awk.g.y"
                { PUTS("/r/"); yyval = yyvsp[-1]; }
#line 2253 "y.tab.c"
    break;

  case 82: /* r: CHAR  */
#line 198 "cmd/awk/awk.g.y"
                        { PUTS("regex CHAR"); yyval = op2(CHAR, (node *) 0, yyvsp[0]); }
#line 2259 "y.tab.c"
    break;

  case 83: /* r: DOT  */
#line 199 "cmd/awk/awk.g.y"
                        { PUTS("regex DOT"); yyval = op2(DOT, (node *) 0, (node *) 0); }
#line 2265 "y.tab.c"
    break;

  case 84: /* r: CCL  */
#line 200 "cmd/awk/awk.g.y"
                        { PUTS("regex CCL"); yyval = op2(CCL, (node *) 0, cclenter(yyvsp[0])); }
#line 2271 "y.tab.c"
    break;

  case 85: /* r: NCCL  */
#line 201 "cmd/awk/awk.g.y"
                        { PUTS("regex NCCL"); yyval = op2(NCCL, (node *) 0, cclenter(yyvsp[0])); }
#line 2277 "y.tab.c"
    break;

  case 86: /* r: '^'  */
#line 202 "cmd/awk/awk.g.y"
                        { PUTS("regex ^"); yyval = op2(CHAR, (node *) 0, HAT); }
#line 2283 "y.tab.c"
    break;

  case 87: /* r: '$'  */
#line 203 "cmd/awk/awk.g.y"
                        { PUTS("regex $"); yyval = op2(CHAR, (node *) 0 ,(node *) 0); }
#line 2289 "y.tab.c"
    break;

  case 88: /* r: r OR r  */
#line 204 "cmd/awk/awk.g.y"
                        { PUTS("regex OR"); yyval = op2(OR, yyvsp[-2], yyvsp[0]); }
#line 2295 "y.tab.c"
    break;

  case 89: /* r: r r  */
#line 206 "cmd/awk/awk.g.y"
                        { PUTS("regex CAT"); yyval = op2(CAT, yyvsp[-1], yyvsp[0]); }
#line 2301 "y.tab.c"
    break;

  case 90: /* r: r STAR  */
#line 207 "cmd/awk/awk.g.y"
                        { PUTS("regex STAR"); yyval = op2(STAR, yyvsp[-1], (node *) 0); }
#line 2307 "y.tab.c"
    break;

  case 91: /* r: r PLUS  */
#line 208 "cmd/awk/awk.g.y"
                        { PUTS("regex PLUS"); yyval = op2(PLUS, yyvsp[-1], (node *) 0); }
#line 2313 "y.tab.c"
    break;

  case 92: /* r: r QUEST  */
#line 209 "cmd/awk/awk.g.y"
                        { PUTS("regex QUEST"); yyval = op2(QUEST, yyvsp[-1], (node *) 0); }
#line 2319 "y.tab.c"
    break;

  case 93: /* r: '(' r ')'  */
#line 210 "cmd/awk/awk.g.y"
                        { PUTS("(regex)"); yyval = yyvsp[-1]; }
#line 2325 "y.tab.c"
    break;

  case 94: /* rel_expr: expr RELOP expr  */
#line 215 "cmd/awk/awk.g.y"
                { PUTS("expr relop expr"); yyval = op2(yyvsp[-1], yyvsp[-2], yyvsp[0]); }
#line 2331 "y.tab.c"
    break;

  case 95: /* rel_expr: '(' rel_expr ')'  */
#line 217 "cmd/awk/awk.g.y"
                { PUTS("(relexpr)"); yyval = yyvsp[-1]; }
#line 2337 "y.tab.c"
    break;

  case 98: /* simple_stat: PRINT print_list redir expr  */
#line 227 "cmd/awk/awk.g.y"
                { PUTS("print>stat"); yyval = stat3(yyvsp[-3], yyvsp[-2], yyvsp[-1], yyvsp[0]); }
#line 2343 "y.tab.c"
    break;

  case 99: /* simple_stat: PRINT print_list  */
#line 229 "cmd/awk/awk.g.y"
                { PUTS("print list"); yyval = stat3(yyvsp[-1], yyvsp[0], nullstat, nullstat); }
#line 2349 "y.tab.c"
    break;

  case 100: /* simple_stat: PRINTF print_list redir expr  */
#line 231 "cmd/awk/awk.g.y"
                { PUTS("printf>stat"); yyval = stat3(yyvsp[-3], yyvsp[-2], yyvsp[-1], yyvsp[0]); }
#line 2355 "y.tab.c"
    break;

  case 101: /* simple_stat: PRINTF print_list  */
#line 233 "cmd/awk/awk.g.y"
                { PUTS("printf list"); yyval = stat3(yyvsp[-1], yyvsp[0], nullstat, nullstat); }
#line 2361 "y.tab.c"
    break;

  case 102: /* simple_stat: expr  */
#line 234 "cmd/awk/awk.g.y"
                { PUTS("expr"); yyval = exptostat(yyvsp[0]); }
#line 2367 "y.tab.c"
    break;

  case 103: /* simple_stat: %empty  */
#line 235 "cmd/awk/awk.g.y"
                        { PUTS("null simple statement"); yyval = nullstat; }
#line 2373 "y.tab.c"
    break;

  case 104: /* simple_stat: error  */
#line 236 "cmd/awk/awk.g.y"
                        { yyclearin; yyerror("illegal statement"); }
#line 2379 "y.tab.c"
    break;

  case 105: /* statement: simple_stat st  */
#line 240 "cmd/awk/awk.g.y"
                                { PUTS("simple stat"); }
#line 2385 "y.tab.c"
    break;

  case 106: /* statement: if statement  */
#line 241 "cmd/awk/awk.g.y"
                                { PUTS("if stat"); yyval = stat3(IF, yyvsp[-1], yyvsp[0], nullstat); }
#line 2391 "y.tab.c"
    break;

  case 107: /* statement: if statement else statement  */
#line 243 "cmd/awk/awk.g.y"
                { PUTS("if-else stat"); yyval = stat3(IF, yyvsp[-3], yyvsp[-2], yyvsp[0]); }
#line 2397 "y.tab.c"
    break;

  case 108: /* statement: while statement  */
#line 244 "cmd/awk/awk.g.y"
                                { PUTS("while stat"); yyval = stat2(WHILE, yyvsp[-1], yyvsp[0]); }
#line 2403 "y.tab.c"
    break;

  case 109: /* statement: for  */
#line 245 "cmd/awk/awk.g.y"
                                { PUTS("for stat"); }
#line 2409 "y.tab.c"
    break;

  case 110: /* statement: NEXT st  */
#line 246 "cmd/awk/awk.g.y"
                                { PUTS("next"); yyval = genjump(NEXT); }
#line 2415 "y.tab.c"
    break;

  case 111: /* statement: EXIT st  */
#line 247 "cmd/awk/awk.g.y"
                                { PUTS("exit"); yyval = genjump(EXIT); }
#line 2421 "y.tab.c"
    break;

  case 112: /* statement: BREAK st  */
#line 248 "cmd/awk/awk.g.y"
                                { PUTS("break"); yyval = genjump(BREAK); }
#line 2427 "y.tab.c"
    break;

  case 113: /* statement: CONTINUE st  */
#line 249 "cmd/awk/awk.g.y"
                                { PUTS("continue"); yyval = genjump(CONTINUE); }
#line 2433 "y.tab.c"
    break;

  case 114: /* statement: '{' stat_list '}'  */
#line 250 "cmd/awk/awk.g.y"
                                { PUTS("{statlist}"); yyval = yyvsp[-1]; }
#line 2439 "y.tab.c"
    break;

  case 115: /* stat_list: stat_list statement  */
#line 254 "cmd/awk/awk.g.y"
                                { PUTS("stat_list stat"); yyval = linkum(yyvsp[-1], yyvsp[0]); }
#line 2445 "y.tab.c"
    break;

  case 116: /* stat_list: %empty  */
#line 255 "cmd/awk/awk.g.y"
                                { PUTS("null stat list"); yyval = nullstat; }
#line 2451 "y.tab.c"
    break;

  case 117: /* while: WHILE '(' conditional ')' optNL  */
#line 259 "cmd/awk/awk.g.y"
                                                { PUTS("while(cond)"); yyval = yyvsp[-2]; }
#line 2457 "y.tab.c"
    break;

  case 118: /* for: FOR '(' simple_stat ';' conditional ';' simple_stat ')' optNL statement  */
#line 264 "cmd/awk/awk.g.y"
                { PUTS("for(e;e;e)"); yyval = stat4(FOR, yyvsp[-7], yyvsp[-5], yyvsp[-3], yyvsp[0]); }
#line 2463 "y.tab.c"
    break;

  case 119: /* for: FOR '(' simple_stat ';' ';' simple_stat ')' optNL statement  */
#line 266 "cmd/awk/awk.g.y"
                { PUTS("for(e;e;e)"); yyval = stat4(FOR, yyvsp[-6], nullstat, yyvsp[-3], yyvsp[0]); }
#line 2469 "y.tab.c"
    break;

  case 120: /* for: FOR '(' VAR IN VAR ')' optNL statement  */
#line 268 "cmd/awk/awk.g.y"
                { PUTS("for(v in v)"); yyval = stat3(IN, yyvsp[-5], yyvsp[-3], yyvsp[0]); }
#line 2475 "y.tab.c"
    break;


#line 2479 "y.tab.c"

      default: break;
    }
  /* User semantic actions sometimes alter yychar, and that requires
     that yytoken be updated with the new translation.  We take the
     approach of translating immediately before every use of yytoken.
     One alternative is translating here after every semantic action,
     but that translation would be missed if the semantic action invokes
     YYABORT, YYACCEPT, or YYERROR immediately after altering yychar or
     if it invokes YYBACKUP.  In the case of YYABORT or YYACCEPT, an
     incorrect destructor might then be invoked immediately.  In the
     case of YYERROR or YYBACKUP, subsequent parser actions might lead
     to an incorrect destructor call or verbose syntax error message
     before the lookahead is translated.  */
  YY_SYMBOL_PRINT ("-> $$ =", YY_CAST (yysymbol_kind_t, yyr1[yyn]), &yyval, &yyloc);

  YYPOPSTACK (yylen);
  yylen = 0;

  *++yyvsp = yyval;

  /* Now 'shift' the result of the reduction.  Determine what state
     that goes to, based on the state we popped back to and the rule
     number reduced by.  */
  {
    const int yylhs = yyr1[yyn] - YYNTOKENS;
    const int yyi = yypgoto[yylhs] + *yyssp;
    yystate = (0 <= yyi && yyi <= YYLAST && yycheck[yyi] == *yyssp
               ? yytable[yyi]
               : yydefgoto[yylhs]);
  }

  goto yynewstate;


/*--------------------------------------.
| yyerrlab -- here on detecting error.  |
`--------------------------------------*/
yyerrlab:
  /* Make sure we have latest lookahead translation.  See comments at
     user semantic actions for why this is necessary.  */
  yytoken = yychar == YYEMPTY ? YYSYMBOL_YYEMPTY : YYTRANSLATE (yychar);
  /* If not already recovering from an error, report this error.  */
  if (!yyerrstatus)
    {
      ++yynerrs;
      yyerror (YY_("syntax error"));
    }

  if (yyerrstatus == 3)
    {
      /* If just tried and failed to reuse lookahead token after an
         error, discard it.  */

      if (yychar <= YYEOF)
        {
          /* Return failure if at end of input.  */
          if (yychar == YYEOF)
            YYABORT;
        }
      else
        {
          yydestruct ("Error: discarding",
                      yytoken, &yylval);
          yychar = YYEMPTY;
        }
    }

  /* Else will try to reuse lookahead token after shifting the error
     token.  */
  goto yyerrlab1;


/*---------------------------------------------------.
| yyerrorlab -- error raised explicitly by YYERROR.  |
`---------------------------------------------------*/
yyerrorlab:
  /* Pacify compilers when the user code never invokes YYERROR and the
     label yyerrorlab therefore never appears in user code.  */
  if (0)
    YYERROR;
  ++yynerrs;

  /* Do not reclaim the symbols of the rule whose action triggered
     this YYERROR.  */
  YYPOPSTACK (yylen);
  yylen = 0;
  YY_STACK_PRINT (yyss, yyssp);
  yystate = *yyssp;
  goto yyerrlab1;


/*-------------------------------------------------------------.
| yyerrlab1 -- common code for both syntax error and YYERROR.  |
`-------------------------------------------------------------*/
yyerrlab1:
  yyerrstatus = 3;      /* Each real token shifted decrements this.  */

  /* Pop stack until we find a state that shifts the error token.  */
  for (;;)
    {
      yyn = yypact[yystate];
      if (!yypact_value_is_default (yyn))
        {
          yyn += YYSYMBOL_YYerror;
          if (0 <= yyn && yyn <= YYLAST && yycheck[yyn] == YYSYMBOL_YYerror)
            {
              yyn = yytable[yyn];
              if (0 < yyn)
                break;
            }
        }

      /* Pop the current state because it cannot handle the error token.  */
      if (yyssp == yyss)
        YYABORT;


      yydestruct ("Error: popping",
                  YY_ACCESSING_SYMBOL (yystate), yyvsp);
      YYPOPSTACK (1);
      yystate = *yyssp;
      YY_STACK_PRINT (yyss, yyssp);
    }

  YY_IGNORE_MAYBE_UNINITIALIZED_BEGIN
  *++yyvsp = yylval;
  YY_IGNORE_MAYBE_UNINITIALIZED_END


  /* Shift the error token.  */
  YY_SYMBOL_PRINT ("Shifting", YY_ACCESSING_SYMBOL (yyn), yyvsp, yylsp);

  yystate = yyn;
  goto yynewstate;


/*-------------------------------------.
| yyacceptlab -- YYACCEPT comes here.  |
`-------------------------------------*/
yyacceptlab:
  yyresult = 0;
  goto yyreturnlab;


/*-----------------------------------.
| yyabortlab -- YYABORT comes here.  |
`-----------------------------------*/
yyabortlab:
  yyresult = 1;
  goto yyreturnlab;


/*-----------------------------------------------------------.
| yyexhaustedlab -- YYNOMEM (memory exhaustion) comes here.  |
`-----------------------------------------------------------*/
yyexhaustedlab:
  yyerror (YY_("memory exhausted"));
  yyresult = 2;
  goto yyreturnlab;


/*----------------------------------------------------------.
| yyreturnlab -- parsing is finished, clean up and return.  |
`----------------------------------------------------------*/
yyreturnlab:
  if (yychar != YYEMPTY)
    {
      /* Make sure we have latest lookahead translation.  See comments at
         user semantic actions for why this is necessary.  */
      yytoken = YYTRANSLATE (yychar);
      yydestruct ("Cleanup: discarding lookahead",
                  yytoken, &yylval);
    }
  /* Do not reclaim the symbols of the rule whose action triggered
     this YYABORT or YYACCEPT.  */
  YYPOPSTACK (yylen);
  YY_STACK_PRINT (yyss, yyssp);
  while (yyssp != yyss)
    {
      yydestruct ("Cleanup: popping",
                  YY_ACCESSING_SYMBOL (+*yyssp), yyvsp);
      YYPOPSTACK (1);
    }
#ifndef yyoverflow
  if (yyss != yyssa)
    YYSTACK_FREE (yyss);
#endif

  return yyresult;
}

#line 271 "cmd/awk/awk.g.y"

