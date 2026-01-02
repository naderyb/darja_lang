%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

%%

"abda"        { return ABDA; }
"akteb"       { return AKTEB; }
"dir"         { return DIR; }
"a9ra"        { return A9RA; }
"ida"         { return IDA; }       // if
"wela_ida"    { return WELA_IDA; }  // else if
"wela"        { return WELA; }      // else
"medem"       { return MEDEM; }     // while
"pour"        { return POUR; }      // for
"mn"          { return MN; } // for loop start
"a"           { return A_TO; }      // for loop end
"wa"          { return AND_OP; }    // logical and
"aw"          { return OR_OP; }     // logical or
"!"           { return NOT_OP; }    // logical not

"=="          { return EQ_OP; }
"!="          { return NE_OP; }
"<="          { return LE_OP; }
">="          { return GE_OP; }
"<"           { return '<'; }
">"           { return '>'; }

[0-9]+        { yylval.ival = atoi(yytext); return NUM; }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.str = strdup(yytext); return ID; }

"="           { return ASSIGN; }
"+"           { return PLUS; }
"-"           { return MINUS; }
"*"           { return MULT; }
"/"           { return DIV; }
"%"           { return MOD; }

\"[^\"]*\"    { yylval.str = strdup(yytext); return STRING; }

[ \t]+        { /* ignore spaces */ }
\n            { return NEWLINE; }

.             { return *yytext; }
%%

int yywrap() { return 1; }
