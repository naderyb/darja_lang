#include <stdio.h>

extern FILE *yyin;
int yyparse(void);

int main() {
    printf("DarjaLang v0.4 interactive mode\n");
    printf("Type your program line by line. Finish with 'khlas' on a line.\n");

    yyin = stdin;
    yyparse();

    printf("\nAppuyez sur Entree pour quitter...");
    getchar();  // wait for user to press Enter

    printf("Program finished!\n");
    return 0;
}
