# DarjaLang 🇩🇿

A tiny toy programming language inspired by **Darija** (Algerian Arabic), built with **Flex** + **Bison** + **C**.

DarjaLang is an interpreter: it reads your program, builds an AST, then executes it in memory.

---

## 🚀 Quick Demo

### Interactive session

```txt
DarjaLang interactive mode
Type your program line by line. Finish with 'khlas' on a line.
abda
akteb("wsh likip")
khlas

wsh likip

Appuyez sur Entree pour quitter...
```

> Convention: you type your program, then put `khlas` on its own line to say “I’m done”.  
> After that, DarjaLang runs the program and prints the output.

---

## ✨ Language Overview

- **Entry point**: `abda` (begin)
- **Print**: `akteb(...)`
- **Variables**: `dir x = ...`
- **Input**: `a9ra()`
- **Conditions**: `ida`, `wela_ida`, `wela`
- **Loops**: `medem` (while), `pour ... mn ... a ...` (for)
- **Operators**: `+ - * / %`, comparisons, logical `wa`, `aw`, `!`

DarjaLang is intentionally small and easy to read: perfect for experiments and learning parsers / interpreters.

---

## 🧱 Syntax Reference

### 1. Program structure

A program always **starts with** `abda`:

```txt
abda
akteb("salam")
```

In interactive mode, you finish entering the program with a line containing:

```txt
khlas
```

Then the interpreter executes everything.

---

### 2. Printing

Use `akteb(...)`:

```txt
akteb("salam")          // print a string
akteb(42)               // print a number
akteb(5 + 7)            // print the result of an expression
```

Strings use double quotes `"..."`.  
Numbers are integers.

---

### 3. Variables and assignment

Use `dir` to declare / assign:

```txt
dir x = 5
dir y = x + 3
akteb(y)         // 8
```

Technically, `dir` is implemented as “declare-or-update”:

- If the variable does not exist, it is created.
- If it exists, its value is updated.

---

### 4. Reading input

Use `a9ra()` to read an integer from stdin:

```txt
dir age = a9ra()
akteb(age)
```

Example interactive run:

```txt
abda
dir age = a9ra()
akteb(age)
khlas

21
21
```

---

### 5. Expressions

Supported operators:

- **Arithmetic**: `+  -  *  /  %`
- **Comparison**:
  - `==` (equal)
  - `!=` (not equal)
  - `<`, `>`, `<=`, `>=`
- **Logical**:
  - `wa` → logical AND
  - `aw` → logical OR
  - `!` → logical NOT (unary)

Examples:

```txt
dir a = 5 + 3 * 2       // 11
dir b = (5 + 3) * 2     // 16

dir ok = (a < b) wa (b == 16)
dir nope = !ok
```

---

### 6. If / Else (conditions)

Keywords:

- `ida` → if
- `wela_ida` → else if
- `wela` → else

Blocks use `{ ... }`.

#### Simple if

```txt
ida (x > 0) {
    akteb("positive")
}
```

#### If / else

```txt
ida (x > 0) {
    akteb("positive")
} wela {
    akteb("non-positive")
}
```

#### If / else if / else

```txt
ida (x > 0) {
    akteb("positive")
} wela_ida (x == 0) {
    akteb("zero")
} wela {
    akteb("negative")
}
```

(Internally, `wela_ida` is parsed as chained `if` blocks.)

---

### 7. While loop – `medem`

`medem (condition) { ... }` behaves like `while`:

```txt
dir i = 0
medem (i < 5) {
    akteb(i)
    dir i = i + 1
}
```

Output:

```txt
0
1
2
3
4
```

---

### 8. For loop – `pour ... mn ... a ...`

Syntax:

```txt
pour i mn 0 a 5 {
    akteb(i)
}
```

Semantics (roughly):

```txt
dir i = 0         // init
medem (i <= 5) {  // condition
    akteb(i)      // body
    dir i = i + 1 // update
}
```

So the loop is **inclusive** on the upper bound (`<=`).

---

## 🧪 Full Example

### Example: sum of numbers from 1 to N

```txt
abda
akteb("3tini N:")
dir N = a9ra()

dir sum = 0

pour i mn 1 a N {
    dir sum = sum + i
}

akteb("sum:")
akteb(sum)
khlas
```

Example run:

```txt
DarjaLang v0.4 interactive mode
Type your program line by line. Finish with 'khlas' on a line.
abda
akteb("3tini N:")
dir N = a9ra()
dir sum = 0
pour i mn 1 a N {
dir sum = sum + i
}
akteb("sum:")
akteb(sum)
khlas

3tini N:
5
sum:
15

Appuyez sur Entree pour quitter...
```

---

## 🛠️ Build & Run

### Prerequisites

- **flex**
- **bison**
- **gcc** (or any C compiler)

### Build

From `c:\Users\youb nader\Desktop\darja_lang`:

```bash
bison -d parser.y
flex lexer.l
gcc main.c parser.tab.c lex.yy.c -o darjalang
```

This produces an executable `darjalang`.

### Run

```bash
./darjalang
```

Then type your program:

```txt
DarjaLang v0.4 interactive mode
Type your program line by line. Finish with 'khlas' on a line.
abda
akteb("salam")
khlas

salam

Appuyez sur Entree pour quitter...
```

Press **Enter** once more to exit.

---

## 🧬 Implementation Notes

High-level architecture:

1. **Lexer** (`lexer.l`, Flex)

   - Recognizes keywords: `abda`, `akteb`, `dir`, `a9ra`, `ida`, `wela_ida`, `wela`, `medem`, `pour`, `mn`, `a`, `wa`, `aw`, `!`, operators, numbers, identifiers, strings, newlines.
   - Produces tokens for Bison.

2. **Parser** (`parser.y`, Bison)

   - Grammar for:
     - Program (`abda` + statements)
     - Statements: print, variable declaration, if, while, for
     - Expressions: arithmetic, comparison, logical, `a9ra()`
   - Builds an **AST**:
     - `Expr` nodes: numbers, variables, binary ops, read.
     - `Stmt` nodes: print, var decl, if, while, for.

3. **Interpreter** (in `parser.y`)

   - Walks the AST:
     - Evaluates expressions (`eval_expr`)
     - Executes statements (`exec_stmt_list`)
     - Manages variables in a linked-list symbol table.
   - Frees memory (`free_expr`, `free_stmt_list`) after execution.

4. **Driver** (`main.c`)
   - Prints intro message.
   - Sets `yyin = stdin`, calls `yyparse()`.
   - Waits for Enter before quitting.

---

## 📦 Roadmap / Ideas

Some possible future features:

- Functions (`dalla` / `reje3`) and user-defined procedures.
- Arrays / lists.
- More data types (booleans, strings with operations, etc.).

---

## 🤝 Contributing

This is a learning / experimental project.  
Feel free to:

- Experiment with the grammar in `parser.y`.
- Extend the lexer in `lexer.l`.
- Add new statement or expression types to the AST.

```txt
[ DarjaLang ]=====>[ Parser ]=====>[ AST ]=====>[ Execution ]
         (Darija)         (Bison)        (in memory)   (C code)
```
