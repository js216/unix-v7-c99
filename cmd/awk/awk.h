/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

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

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_Y_TAB_H_INCLUDED
# define YY_YY_Y_TAB_H_INCLUDED
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


#endif /* !YY_YY_Y_TAB_H_INCLUDED  */
