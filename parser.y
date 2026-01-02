%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int yylex(void);

// Linked list to store statements until 'khlas'
typedef struct Node {
    char *str;
    struct Node *next;
} Node;

Node *program_list = NULL;

// Symbol table for variables
typedef struct Var {
    char *name;
    int value;
    struct Var *next;
} Var;

Var *var_list = NULL;

// ----- AST for deferred execution -----
typedef enum { STMT_PRINT, STMT_VAR_DECL } StmtType;
typedef enum { EXPR_NUM, EXPR_VAR, EXPR_BINOP, EXPR_READ } ExprType;

typedef struct Expr Expr;
typedef struct Stmt Stmt;

struct Expr {
    ExprType type;
    int ival;        // for numbers
    char *name;      // for variables
    int op;          // '+', '-', '*', '/', '%'
    Expr *left;
    Expr *right;
};

struct Stmt {
    StmtType type;
    Stmt *next;
    union {
        struct { char *var_name; Expr *expr; } var_decl;
        struct { int is_string; char *str; Expr *expr; } print;
    } u;
};

Stmt *program_head = NULL;
Stmt *program_tail = NULL;

// Old helper (no longer used, kept for compatibility)
void add_print_node(char *s) {
    Node *n = malloc(sizeof(Node));
    n->str = s;
    n->next = NULL;
    if (!program_list) {
        program_list = n;
    } else {
        Node *curr = program_list;
        while (curr->next) curr = curr->next;
        curr->next = n;
    }
}

// AST helpers
static void add_statement(Stmt *s) {
    if (!s) return;
    if (!program_head) {
        program_head = program_tail = s;
    } else {
        program_tail->next = s;
        program_tail = s;
    }
}

static Expr *make_num_expr(int v) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_NUM;
    e->ival = v;
    e->name = NULL;
    e->op = 0;
    e->left = e->right = NULL;
    return e;
}

static Expr *make_var_expr(char *name) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_VAR;
    e->ival = 0;
    e->name = name;  // take ownership
    e->op = 0;
    e->left = e->right = NULL;
    return e;
}

static Expr *make_binop_expr(int op, Expr *l, Expr *r) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_BINOP;
    e->ival = 0;
    e->name = NULL;
    e->op = op;
    e->left = l;
    e->right = r;
    return e;
}

static Expr *make_read_expr(void) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_READ;
    e->ival = 0;
    e->name = NULL;
    e->op = 0;
    e->left = e->right = NULL;
    return e;
}

static Stmt *make_var_decl(char *name, Expr *expr) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_VAR_DECL;
    s->next = NULL;
    s->u.var_decl.var_name = name; // take ownership
    s->u.var_decl.expr = expr;
    return s;
}

static Stmt *make_print_expr_stmt(Expr *expr) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_PRINT;
    s->next = NULL;
    s->u.print.is_string = 0;
    s->u.print.str = NULL;
    s->u.print.expr = expr;
    return s;
}

static Stmt *make_print_string_stmt(char *str) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_PRINT;
    s->next = NULL;
    s->u.print.is_string = 1;
    s->u.print.str = str;  // take ownership
    s->u.print.expr = NULL;
    return s;
}

static int eval_expr(Expr *e);

// Execute all stored statements (after 'khlas')
void execute_program() {
    Stmt *curr = program_head;
    while (curr) {
        switch (curr->type) {
        case STMT_VAR_DECL: {
            int v = eval_expr(curr->u.var_decl.expr);
            set_var_value(curr->u.var_decl.var_name, v);
            break;
        }
        case STMT_PRINT:
            if (curr->u.print.is_string) {
                printf("%s\n", curr->u.print.str);
            } else {
                int v = eval_expr(curr->u.print.expr);
                printf("%d\n", v);
            }
            break;
        }
        Stmt *tmp = curr;
        curr = curr->next;
        // free stmt + owned data
        if (tmp->type == STMT_VAR_DECL) {
            free(tmp->u.var_decl.var_name);
            // free expr tree below
        } else if (tmp->type == STMT_PRINT) {
            if (tmp->u.print.is_string) {
                free(tmp->u.print.str);
            }
        }
        // free expr trees
        // simple recursive free
        void free_expr(Expr *e) {
            if (!e) return;
            if (e->type == EXPR_BINOP) {
                free_expr(e->left);
                free_expr(e->right);
            }
            if (e->type == EXPR_VAR && e->name) {
                free(e->name);
            }
            free(e);
        }
        if (tmp->type == STMT_VAR_DECL) {
            free_expr(tmp->u.var_decl.expr);
        } else if (!tmp->u.print.is_string) {
            free_expr(tmp->u.print.expr);
        }
        free(tmp);
    }
    program_head = program_tail = NULL;
    // old Node list is unused now
}

// Variable helpers
int get_var_value(const char *name) {
    Var *curr = var_list;
    while(curr) {
        if(strcmp(curr->name,name)==0) return curr->value;
        curr = curr->next;
    }
    fprintf(stderr,"خطأ: variable %s not found\n", name);
    return 0;
}

void set_var_value(const char *name, int value) {
    Var *curr = var_list;
    while(curr) {
        if(strcmp(curr->name,name)==0) {
            curr->value = value;
            return;
        }
        curr = curr->next;
    }
    // new variable
    Var *v = malloc(sizeof(Var));
    v->name = strdup(name);
    v->value = value;
    v->next = var_list;
    var_list = v;
}

// expression evaluator (called at execution time)
static int eval_expr(Expr *e) {
    switch (e->type) {
    case EXPR_NUM:
        return e->ival;
    case EXPR_VAR:
        return get_var_value(e->name);
    case EXPR_BINOP: {
        int l = eval_expr(e->left);
        int r = eval_expr(e->right);
        switch (e->op) {
        case '+': return l + r;
        case '-': return l - r;
        case '*': return l * r;
        case '/': return r != 0 ? l / r : 0;
        case '%': return r != 0 ? l % r : 0;
        default:  return 0;
        }
    }
    case EXPR_READ: {
        int tmp;
        scanf("%d", &tmp);
        return tmp;
    }
    default:
        return 0;
    }
}
%}

%union {
    char* str;
    int ival;
    Stmt* stmt;
    Expr* expr;
}

%token ABDA KHLAS AKTEB DIR A9RA
%token NEWLINE
%token <str> STRING ID
%token <ival> NUM
%token ASSIGN PLUS MINUS MULT DIV MOD

/* operator precedence and associativity:
   support both named tokens and literal operators */
%left PLUS MINUS '+' '-'
%left MULT DIV MOD '*' '/' '%'

%type <stmt> statement print_stmt var_decl
%type <expr> expr

%%

program:
      ABDA block end_program
    | ABDA statements end_program
;

end_program:
      KHLAS opt_newlines { execute_program(); }
;

opt_newlines:
      /* empty */
    | opt_newlines NEWLINE
;

block:
      '{' statements '}'
;

statements:
      /* empty */
    | statements statement NEWLINE   { add_statement($2); }  /* normal statement line */
    | statements NEWLINE             { /* blank line */ }
;

statement:
      print_stmt { $$ = $1; }
    | var_decl  { $$ = $1; }
;

/* allow either ASSIGN token or literal '=' */
var_decl:
      DIR ID ASSIGN expr { $$ = make_var_decl($2, $4); }
    | DIR ID '='    expr { $$ = make_var_decl($2, $4); }
;

print_stmt:
      AKTEB '(' expr ')' {
          $$ = make_print_expr_stmt($3);
      }
    | AKTEB '(' STRING ')' {
          char *s = $3;
          size_t len = strlen(s);
          if(len>=2 && s[0]=='"' && s[len-1]=='"') {
              s[len-1]='\0';
              memmove(s, s+1, len);
          }
          $$ = make_print_string_stmt(s);
      }
;

/* allow both named operator tokens and literal operators; build AST */
expr:
      NUM       { $$ = make_num_expr($1); }
    | ID        { $$ = make_var_expr($1); }
    | expr PLUS expr  { $$ = make_binop_expr('+', $1, $3); }
    | expr MINUS expr { $$ = make_binop_expr('-', $1, $3); }
    | expr MULT expr  { $$ = make_binop_expr('*', $1, $3); }
    | expr DIV expr   { $$ = make_binop_expr('/', $1, $3); }
    | expr MOD expr   { $$ = make_binop_expr('%', $1, $3); }
    | expr '+' expr   { $$ = make_binop_expr('+', $1, $3); }
    | expr '-' expr   { $$ = make_binop_expr('-', $1, $3); }
    | expr '*' expr   { $$ = make_binop_expr('*', $1, $3); }
    | expr '/' expr   { $$ = make_binop_expr('/', $1, $3); }
    | expr '%' expr   { $$ = make_binop_expr('%', $1, $3); }
    | A9RA '(' ')'    { $$ = make_read_expr(); }
;

%%

void yyerror(const char *s) {
    fprintf(stderr,"error: %s\n", s);
}
