%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

%%

"abda"      { return ABDA; }
"akteb"     { return AKTEB; }
"dir"       { return DIR; }
"a9ra"      { return A9RA; }

[0-9]+      { yylval.ival = atoi(yytext); return NUM; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.str = strdup(yytext); return ID; }

"="         { return ASSIGN; }
"+"         { return PLUS; }
"-"         { return MINUS; }
"*"         { return MULT; }
"/"         { return DIV; }
"%"         { return MOD; }

\"[^\"]*\"  { yylval.str = strdup(yytext); return STRING; }

[ \t]+      { /* ignore spaces */ }
\n          { return NEWLINE; }

.           { return *yytext; }  // literal char
%%

int yywrap() {
    return 1;
}