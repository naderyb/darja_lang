%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void yyerror(const char *s);
int yylex(void);
void set_var_value(const char *name, int value);  // forward declaration

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

/*new word: AST= abstract syntax tree*/

// ----- AST for deferred execution -----
typedef enum { STMT_PRINT, STMT_VAR_DECL, STMT_IF, STMT_WHILE, STMT_FOR } StmtType;
typedef enum { EXPR_NUM, EXPR_VAR, EXPR_BINOP, EXPR_READ, EXPR_LOGICAL } ExprType;

// forward declarations for structs are now provided via %code requires
struct Expr {
    ExprType type;
    int ival; // for numbers
    char *name; // for variables
    int op; // '+', '-', '*', '/', '%'
    struct Expr *left;
    struct Expr *right;
};

struct Stmt {
    StmtType type;
    struct Stmt *next;
    union {
        struct { char *var_name; struct Expr *expr; } var_decl;
        struct { int is_string; char *str; struct Expr *expr; } print;
        // if / while
        struct { struct Expr *cond; struct Stmt *then_branch; struct Stmt *else_branch; } if_stmt;
        struct { struct Expr *cond; struct Stmt *body; } while_stmt;
        struct { struct Stmt *init; struct Expr *cond; struct Stmt *update; struct Stmt *body; } for_stmt;
    } u;
};

typedef struct Expr Expr;
typedef struct Stmt Stmt;

/* global program list head/tail for AST statements */
Stmt *program_head = NULL;
Stmt *program_tail = NULL;

static void add_statement(Stmt *s) {
    if (!s) return;
    if (!program_head) {
        program_head = program_tail = s;
    } else {
        program_tail->next = s;
        program_tail = s;
    }
}

// builder for number expression
static Expr *make_num_expr(int v) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_NUM;
    e->ival = v;
    e->name = NULL;
    e->op = 0;
    e->left = e->right = NULL;
    return e;
}

// builder for variable expression
static Expr *make_var_expr(char *name) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_VAR;
    e->ival = 0;
    e->name = name;  // take ownership
    e->op = 0;
    e->left = e->right = NULL;
    return e;
}

// builder for binary operation expression 
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

// builder for read expression
static Expr *make_read_expr(void) {
    Expr *e = malloc(sizeof(Expr));
    e->type = EXPR_READ;
    e->ival = 0;
    e->name = NULL;
    e->op = 0;
    e->left = e->right = NULL;
    return e;
}

// builder for variable declaration statement
static Stmt *make_var_decl(char *name, Expr *expr) {
    Stmt *s = malloc(sizeof(Stmt)); // allocate statement (LAAAAZM also balak tensa free apres execution)
    s->type = STMT_VAR_DECL; // variable declaration type
    s->next = NULL; // no next yet
    s->u.var_decl.var_name = name; // take ownership
    s->u.var_decl.expr = expr; // expression for initial value
    return s; // return the statement (hhhhh nssit hedi w ga3d fig t3 2days)
}

// hedi dertha to print expression statement
static Stmt *make_print_expr_stmt(Expr *expr) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_PRINT;
    s->next = NULL;
    s->u.print.is_string = 0;
    s->u.print.str = NULL;
    s->u.print.expr = expr;
    return s;
}

// hedi dertha to print string statement
static Stmt *make_print_string_stmt(char *str) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_PRINT; // print string
    s->next = NULL; // no next yet
    s->u.print.is_string = 1; // it's a string wooooooooooy(ana 7mar)
    s->u.print.str = str; // take ownership
    s->u.print.expr = NULL; // no expr
    return s; // return the statement
}

// builders for if / while
static Stmt *make_if_stmt(Expr *cond, Stmt *then_branch, Stmt *else_branch) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_IF;
    s->next = NULL;
    s->u.if_stmt.cond = cond;
    s->u.if_stmt.then_branch = then_branch;
    s->u.if_stmt.else_branch = else_branch;
    return s;
}

// builder for while statement
static Stmt *make_while_stmt(Expr *cond, Stmt *body) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_WHILE;
    s->next = NULL;
    s->u.while_stmt.cond = cond;
    s->u.while_stmt.body = body;
    return s;
}

// builder for for statement
static Stmt *make_for_stmt(Stmt *init, Expr *cond, Stmt *update, Stmt *body) {
    Stmt *s = malloc(sizeof(Stmt));
    s->type = STMT_FOR;
    s->next = NULL;
    s->u.for_stmt.init = init;
    s->u.for_stmt.cond = cond;
    s->u.for_stmt.update = update;
    s->u.for_stmt.body = body;
    return s;
}

//prototype for execute_program
void execute_program(void);

static int eval_expr(Expr *e);
/*free expression tree helper */
static void free_expr(Expr *e);

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
        int l = 0;
        int r = 0;
        if (e->left)  l = eval_expr(e->left);
        if (e->right) r = eval_expr(e->right);
        switch (e->op) {
        case '+': return l + r;
        case '-': return l - r;
        case '*': return l * r;
        case '/': return r != 0 ? l / r : 0;
        case '%': return r != 0 ? l % r : 0;
        /* logical / comparison operators */
        case 'o': return l || r; /* OR */
        case 'a': return l && r; /* AND */
        case '!': return !r; /* NOT (unary, uses right) */
        case '=': return l == r;  /* == */
        case 'n': return l != r;  /* != */
        case '<': return l <  r;
        case '>': return l >  r;
        case 'l': return l <= r;  /* <= */
        case 'g': return l >= r;  /* >= */
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

/* implementation of free_expr (was mn 9bl nested inside execute_program) */
static void free_expr(Expr *e) {
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

// helpers to execute and free statement lists (handle if/while)
static void exec_stmt_list(Stmt *s) {
    for (Stmt *curr = s; curr; curr = curr->next) {
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
        case STMT_IF:
            if (eval_expr(curr->u.if_stmt.cond)) {
                exec_stmt_list(curr->u.if_stmt.then_branch);
            } else if (curr->u.if_stmt.else_branch) {
                exec_stmt_list(curr->u.if_stmt.else_branch);
            }
            break;
        case STMT_WHILE:
            while (eval_expr(curr->u.while_stmt.cond)) {
                exec_stmt_list(curr->u.while_stmt.body);
            }
            break;
        case STMT_FOR:
            if (curr->u.for_stmt.init)
                exec_stmt_list(curr->u.for_stmt.init);
            while (!curr->u.for_stmt.cond || eval_expr(curr->u.for_stmt.cond)) {
                if (curr->u.for_stmt.body)
                    exec_stmt_list(curr->u.for_stmt.body);
                if (curr->u.for_stmt.update)
                    exec_stmt_list(curr->u.for_stmt.update);
            }
            break;
        }
    }
}

// helper to free statement list
static void free_stmt_list(Stmt *s) {
    while (s) {
        Stmt *next = s->next;
        switch (s->type) {
        case STMT_VAR_DECL:
            if (s->u.var_decl.var_name) free(s->u.var_decl.var_name);
            free_expr(s->u.var_decl.expr);
            break;
        case STMT_PRINT:
            if (s->u.print.is_string) {
                if (s->u.print.str) free(s->u.print.str);
            } else {
                free_expr(s->u.print.expr);
            }
            break;
        case STMT_IF:
            free_expr(s->u.if_stmt.cond);
            free_stmt_list(s->u.if_stmt.then_branch);
            if (s->u.if_stmt.else_branch) free_stmt_list(s->u.if_stmt.else_branch);
            break;
        case STMT_WHILE:
            free_expr(s->u.while_stmt.cond);
            free_stmt_list(s->u.while_stmt.body);
            break;
        case STMT_FOR:
            if (s->u.for_stmt.init)
                free_stmt_list(s->u.for_stmt.init);
            if (s->u.for_stmt.cond)
                free_expr(s->u.for_stmt.cond);
            if (s->u.for_stmt.update)
                free_stmt_list(s->u.for_stmt.update);
            if (s->u.for_stmt.body)
                free_stmt_list(s->u.for_stmt.body);
            break;
        }
        free(s);
        s = next;
    }
}

// execute all stored statements
void execute_program() {
    printf("\n");
    exec_stmt_list(program_head);
    free_stmt_list(program_head);
    program_head = program_tail = NULL;
}

%}

/* make Stmt / Expr visible in the generated header before %union */
%code requires {
    typedef struct Stmt Stmt;
    typedef struct Expr Expr;
}

%union {
    char* str;
    int ival;
    Stmt* stmt;
    Expr* expr;
}

/* add new control-flow tokens (already returned by lexer) */
%token ABDA AKTEB DIR A9RA IDA WELA_IDA WELA MEDEM POUR MN A_TO
%token NEWLINE
%token <str> STRING ID
%token <ival> NUM
%token ASSIGN PLUS MINUS MULT DIV MOD
%token AND_OP OR_OP NOT_OP
%token EQ_OP NE_OP LE_OP GE_OP

/* operator precedence and associativity:
   support both named tokens and literal operators */
%left OR_OP
%left AND_OP
%right NOT_OP
%left EQ_OP NE_OP
%left '<' '>' LE_OP GE_OP
%left PLUS MINUS '+' '-'
%left MULT DIV MOD '*' '/' '%'

/* precedence to resolve dangling 'wela' (else) */
%nonassoc IF_NO_WELA
%nonassoc WELA

/* tell bison we intentionally have exactly one S/R conflict */
%expect 1

/* extend stmt types */
%type <stmt> statement print_stmt var_decl if_stmt while_stmt for_stmt block_statements
%type <expr> expr

%%

/* Execute + accept when the program input ends (EOF), not on 'khlas' */
program:
      ABDA block opt_newlines {
          execute_program();
          YYACCEPT;
      }
    | ABDA statements opt_newlines {
          execute_program();
          YYACCEPT;
      }
;

opt_newlines:
      /* empty */
    | opt_newlines NEWLINE
;

block:
      '{' statements '}'
;

/* top-level statements still fill the global program list */
statements:
      /* empty */
    | statements statement NEWLINE   { add_statement($2); }  /* normal statement line */
    | statements NEWLINE             { /* blank line */ }
;

/* statements used inside { ... } blocks for if/while */
block_statements:
      /* empty */                         { $$ = NULL; }
    | block_statements statement NEWLINE  {
          if ($1) {
              Stmt *tail = $1;
              while (tail->next) tail = tail->next;
              tail->next = $2;
              $$ = $1;
          } else {
              $$ = $2;
          }
      }
    | block_statements NEWLINE            { $$ = $1; }
;

statement:
      print_stmt  { $$ = $1; }
    | var_decl   { $$ = $1; }
    | if_stmt    { $$ = $1; }
    | while_stmt { $$ = $1; }
    | for_stmt   { $$ = $1; }
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

/* if / else using ida / wela; precedence fixes dangling 'wela' */
if_stmt:
      IDA '(' expr ')' '{' block_statements '}' %prec IF_NO_WELA
          { $$ = make_if_stmt($3, $6, NULL); }
    | IDA '(' expr ')' '{' block_statements '}' WELA '{' block_statements '}'
          { $$ = make_if_stmt($3, $6, $10); }
;

/* while using medem */
while_stmt:
      MEDEM '(' expr ')' '{' block_statements '}' {
          $$ = make_while_stmt($3, $6);
      }
;

/* for statement: pour i allant_de X a Y { ... } */
for_stmt:
      POUR ID MN expr A_TO expr '{' block_statements '}' {
          /* init: dir i = X */
          Stmt *init = make_var_decl($2, $4);
          /* condition: i <= Y  (operator code 'l' for <=) */
          Expr *cond = make_binop_expr('l', make_var_expr(strdup($2)), $6);
          /* update: dir i = i + 1  (reuses var_decl semantics as assignment) */
          Stmt *update = make_var_decl(strdup($2),
              make_binop_expr('+', make_var_expr(strdup($2)), make_num_expr(1)));
          $$ = make_for_stmt(init, cond, update, $8);
      }
;

/* allow both named operator tokens and literal operators; build AST */
expr:
      NUM       { $$ = make_num_expr($1); }
    | ID        { $$ = make_var_expr($1); }
    | A9RA '(' ')'    { $$ = make_read_expr(); }
    | '(' expr ')'    { $$ = $2; }

    /* arithmetic */
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

    /* comparison */
    | expr EQ_OP expr { $$ = make_binop_expr('=', $1, $3); } /* == */
    | expr NE_OP expr { $$ = make_binop_expr('n', $1, $3); } /* != */
    | expr '<'  expr  { $$ = make_binop_expr('<', $1, $3); }
    | expr '>'  expr  { $$ = make_binop_expr('>', $1, $3); }
    | expr LE_OP expr { $$ = make_binop_expr('l', $1, $3); } /* <= */
    | expr GE_OP expr { $$ = make_binop_expr('g', $1, $3); } /* >= */

    /* logical */
    | expr AND_OP expr { $$ = make_binop_expr('a', $1, $3); } /* && */
    | expr OR_OP  expr { $$ = make_binop_expr('o', $1, $3); } /* || */
    | NOT_OP expr      { $$ = make_binop_expr('!', NULL, $2); }
;

%%

void yyerror(const char *s) {
    fprintf(stderr,"error: %s\n", s);
}
