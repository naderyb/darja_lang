%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
%}

%%

"abda"        { return ABDA; } // begin
"akteb"       { return AKTEB; } // print
"dir"         { return DIR; } // assign var
"a9ra"        { return A9RA; } //read
"ida"         { return IDA; } // if
"wela_ida"    { return WELA_IDA; } // else if
"wela"        { return WELA; } // else
"medem"       { return MEDEM; } // while
"pour"        { return POUR; }  // for
"mn"          { return MN; } // for loop start
"a"           { return A_TO; } // for loop end
"wa"          { return AND_OP; } // logical and
"aw"          { return OR_OP; } // logical or
"!"           { return NOT_OP; } // logical not

"=="          { return EQ_OP; } // equality
"!="          { return NE_OP; } // not equal
"<="          { return LE_OP; } // less than or equal
">="          { return GE_OP; } // greater than or equal
"<"           { return '<'; } // less than
">"           { return '>'; } // greater than

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
