#include <stdio.h>

extern FILE *yyin;
int yyparse(void);

int main() {
    printf("DarjaLang v0.4 interactive mode\n");
    printf("Type your program line by line. Finish with 'khlas' on a line.\n");

    yyin = stdin;
    yyparse();

    printf("Program finished!\n");
    return 0;
}
