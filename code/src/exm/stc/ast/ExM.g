/*
 * Copyright 2013 University of Chicago and Argonne National Laboratory
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License
 */
grammar ExM;

options {output=AST;}

tokens {
    PLUS     = '+' ;
    MINUS    = '-' ;
    MULT    = '*' ;
    DIV     = '/' ;
    INTDIV     = '%/' ;
    MOD     = '%%' ;
    POW     = '**' ;
    ASSIGN  = '=';
    MUTATE  = ':=';
    NOT     = '!';
    AND     = '&&';
    OR     = '||';
    EQUALS = '==';
    NEQUALS = '!=';
    GT = '>';
    LT = '<';
    GTE = '>=';
    LTE = '<=';
    NEGATE;
    // Dummy symbols
    PROGRAM;
    DECLARATION;
    DECLARE_VARIABLE_REST;
    DECLARE_ASSIGN;
    MAPPING;
    DEFINE_FUNCTION;
    DEFINE_BUILTIN_FUNCTION;
    DEFINE_APP_FUNCTION;
    DEFINE_NEW_STRUCT_TYPE;
    DEFINE_NEW_TYPE;
    STRUCT_FIELD_DEF;
    VARIABLE;
    MULTI_TYPE;
    INT_LITERAL;
    FLOAT_LITERAL;
    STRING_LITERAL;
    BOOL_LITERAL;
    OCTAL_ESCAPE;
    STATEMENT_CHAIN;
    ASSIGN_EXPRESSION;
    ASSIGN_TARGET;
    CALL_FUNCTION;
    FORMAL_ARGUMENT_LIST;
    ARGUMENT_LIST;
    IDENTIFIER_LIST;
    OPERATOR;
    COMMAND;
    EXPR;
    EXPR_STMT;
    UPDATE;
    IF_STATEMENT;
    SWITCH_STATEMENT;
    FOREACH_LOOP;
    FOR_LOOP;
    FOR_LOOP_INIT;
    FOR_LOOP_UPDATE;
    FOR_LOOP_ASSIGN;
    WAIT_STATEMENT;
    BLOCK;
    ARRAY;
    ARRAY_LOAD;
    STRUCT_LOAD;
    ARRAY_PATH;
    STRUCT_PATH;
    IMPORT_PATH;
    ARRAY_RANGE;
    ARRAY_ELEMS;
    ANNOTATION;
    GLOBAL_CONST;
    TCL_FUN_REF;
    TCL_PACKAGE;
    INLINE_TCL;
    TYPE_PARAMETERS;
    DEPRECATED;
    APP_BODY;
    APP_FILENAME;
    APP_REDIRECTION;
    CALL_ANNOTATION;
}

@parser::header {
package exm.stc.ast.antlr;
import exm.stc.ast.FilePosition;
import exm.stc.ast.FilePosition.LineMapping;

}

@parser::members {
    public boolean parserError = false;
    public LineMapping lineMap = null;

    public void displayRecognitionError(String[] tokenNames,
                                    RecognitionException e) {
      // Log that there was an error, otherwise antlr might
      // recover silently
      parserError = true;
      String hdr;
      /* Use lineMap if available */
      if (lineMap != null) {
        FilePosition realPos = lineMap.getFilePosition(e.line);
        hdr = realPos.file + " l." +
                    realPos.line + ":" + e.charPositionInLine;

      } else {
        hdr = "<preprocessor output> l." +
                    e.line + ":" + e.charPositionInLine;
      }
      String msg = getErrorMessage(e, tokenNames);
      emitErrorMessage(hdr + " " + msg);
    }

    protected Object recoverFromMismatchedToken(IntStream input,
                                            int ttype,
                                            BitSet follow)
    throws RecognitionException {
        throw new MismatchedTokenException(ttype, input);
    }
}

@lexer::header {
package exm.stc.ast.antlr;
import exm.stc.ast.FilePosition;
import exm.stc.ast.FilePosition.LineMapping;
}

@lexer::members {
    /** New token stream for C Preprocessor */
    public static int CPP = 5;
    public LineMapping lineMap = null;
    public boolean quiet = false; // if true, don't report errors

    public void displayRecognitionError(String[] tokenNames,
                                    RecognitionException e) {
      if (quiet) return;
      String hdr;
      /* Use lineMap if available */
      if (lineMap != null) {
        FilePosition realPos = lineMap.getFilePosition(e.line);
        hdr = realPos.file + " l." +
                    realPos.line + ":" + e.charPositionInLine;

      } else {
        hdr = "<preprocessor output> l." +
                    e.line + ":" + e.charPositionInLine;
      }
      String msg = getErrorMessage(e, tokenNames);
      emitErrorMessage(hdr + " " + msg);
    }
}

program:
        top_level_statement* EOF -> ^( PROGRAM top_level_statement* EOF )
    ;

top_level_statement:
        (function_definition |
            new_type_definition |
            global_const_definition |
            import_statement)
    ;

function_definition:
        composite_function_definition
    |   app_function_definition
    |   builtin_function_definition
    ;

new_type_definition:
        TYPE tname=ID LBRACE type_field* RBRACE ->
            ^( DEFINE_NEW_STRUCT_TYPE $tname type_field*)
    |   TYPE tname=ID baset=ID array_marker* SEMICOLON ->
            ^( DEFINE_NEW_TYPE $tname $baset array_marker* )
    |   TYPEDEF tname=ID baset=ID array_marker* SEMICOLON ->
            ^( TYPEDEF $tname $baset array_marker* )
    ;

// Import can a string or a dotted list of identifiers
import_statement:
        IMPORT (
            import_path -> ^( IMPORT import_path ) |
            STRING -> ^( IMPORT STRING ) ) SEMICOLON
    ;

// Identifier path: separated by full stops
import_path:
        ID id_subscript* -> ^( IMPORT_PATH ID id_subscript* )
    ;

type_field:
        type=ID name=ID  array_marker* SEMICOLON ->
            ^( STRUCT_FIELD_DEF $type $name array_marker* )
    ;
app_function_definition:
        annotation*
        APP o=formal_argument_list f=ID i=formal_argument_list
        LBRACE app_body SEMICOLON? RBRACE ->
        ^( DEFINE_APP_FUNCTION $f $o $i app_body annotation* )
    ;

app_body:
    command app_redirection*
        -> ^( APP_BODY command app_redirection* );

// The app function command line
command:
        c=STRING command_args? -> ^( COMMAND $c command_args? )
    ;

command_args:
        command_arg command_args_more
    ;

command_args_more:
        command_args |
    ;

command_arg:
        variable
    |   literal
    |   LPAREN expr RPAREN -> expr
    |   ATSIGN ID -> ^( APP_FILENAME ID )
    ;

app_redirection:
      ATSIGN redirect_type ASSIGN expr ->
        ^( APP_REDIRECTION redirect_type expr )
    ;

redirect_type:
        (STDIN|STDOUT|STDERR)
    ;

composite_function_definition:
        annotation*
        o=formal_argument_list f=ID i=formal_argument_list
        b=block ->
        ^( DEFINE_FUNCTION $f $o $i $b annotation* )
    ;

builtin_function_definition:
        annotation*
        tp=type_parameters
        o=formal_argument_list f=ID i=formal_argument_list
         tcl_package
         tcl_fun_ref? inline_tcl? SEMICOLON ->
        ^( DEFINE_BUILTIN_FUNCTION $f $tp $o $i tcl_package tcl_fun_ref?
                                   inline_tcl? annotation* )
    ;

tcl_package:
        pkg=STRING version=STRING -> ^( TCL_PACKAGE $pkg $version )
    ;

tcl_fun_ref:
        symbol=STRING -> ^( TCL_FUN_REF $symbol )
    ;

type_parameters:
        /* empty */ -> ^( TYPE_PARAMETERS )
    |   LT id_list GT -> ^( TYPE_PARAMETERS id_list )
    ;

id_list:
        ID id_list_more
    ;
id_list_more:
        /* empty */
    |   COMMA id_list -> id_list
    ;
inline_tcl:
    LSQUARE tcl=(STRING|STRING_MULTI_LINE_1|STRING_MULTI_LINE_2) RSQUARE
          -> ^( INLINE_TCL $tcl );

global_const_definition:
        GLOBAL CONST v=declare_assign_single SEMICOLON
            -> ^( GLOBAL_CONST $v )
    ;

formal_argument_list:
        /* empty */ -> ^( FORMAL_ARGUMENT_LIST )
    |   LPAREN formal_arguments? RPAREN ->
            ^( FORMAL_ARGUMENT_LIST formal_arguments? )
    ;

formal_arguments:
        arg_decl formal_arguments_rest*
    ;

formal_arguments_rest:
        COMMA arg_decl
        -> arg_decl
    ;

arg_decl:
    // Match standard declaration AST
        type=multi_type VARARGS? v=ID array_marker*
            -> ^( DECLARATION $type
                ^( DECLARE_VARIABLE_REST $v array_marker* )
                VARARGS?)
    ;

multi_type:
        ID another_type*
            -> ^( MULTI_TYPE ID another_type* )
    ;

another_type:
        PIPE ID -> ID
    ;

    /*|   type=ID VARARGS =ID
            -> ^( VARARGS $type $v )
    |   VARARGS ID? -> ^( VARARGS ID? )
    ;*/

block: LBRACE stmt* RBRACE -> ^( BLOCK stmt* )
    ;


stmt:
        SEMICOLON ->
    |   (real_stmt) -> real_stmt
    ;

real_stmt:
        (stmt_chain)
    |   (if_stmt)
    |   (switch_stmt)
    |   (block)
    |   (foreach_loop)
    |   (for_loop)
    |   (iterate_loop)
    |   (wait_stmt)
    |   (update_stmt)
    ;

stmt_chain:
        chainable_stmt
          (  SEMICOLON
                    -> chainable_stmt
          | stmt_chain_op real_stmt
                    ->  ^( STATEMENT_CHAIN chainable_stmt real_stmt ))
    ;

chainable_stmt:
        (declaration_multi)
    |   (assignment_expr)
    |   (expr_stmt)
    ;

 stmt_chain_op:
        '=' '>'
    ;

if_stmt:
        IF LPAREN c=expr RPAREN b=block else_block? ->
        ^( IF_STATEMENT $c $b else_block? )
    ;

else_block:
        ELSE b=block -> $b
    |   ELSE if_stmt -> ^( BLOCK if_stmt )
    ;

switch_stmt:
        SWITCH LPAREN e=expr RPAREN LBRACE switch_case* RBRACE
        -> ^( SWITCH_STATEMENT $e switch_case* )
    ;

switch_case:
        CASE INTEGER COLON stmt*
        -> ^( CASE INTEGER ^( BLOCK stmt* ) )
    |   DEFAULT COLON stmt*
        -> ^( DEFAULT ^( BLOCK stmt* ) )
    ;

foreach_loop:
        annotation* FOREACH v=ID COMMA i=ID IN e=expr b=block
        -> ^( FOREACH_LOOP $e $b $v $i annotation* )
    |   annotation* FOREACH v=ID IN e=expr b=block
        -> ^( FOREACH_LOOP $e $b $v annotation* )
    ;

for_loop:
        annotation*
        FOR LPAREN i=for_loop_init SEMICOLON c=expr SEMICOLON
                u=for_loop_update RPAREN b=block
            -> ^( FOR_LOOP $i $c $u $b annotation* )
    ;

for_loop_init:
        for_loop_init_items?
            -> ^( FOR_LOOP_INIT for_loop_init_items?)
    ;

for_loop_init_items:
        (for_loop_declaration|for_loop_assignment) (for_loop_init_more)*
    ;

for_loop_init_more:
        COMMA for_loop_declaration -> for_loop_declaration
    |   COMMA for_loop_assignment -> for_loop_assignment
    ;

for_loop_update:
        for_loop_update_items?
            -> ^( FOR_LOOP_UPDATE for_loop_update_items? )
    ;

for_loop_update_items:
        for_loop_assignment for_loop_update_more*
    ;

for_loop_update_more:
        COMMA for_loop_assignment -> for_loop_assignment
    ;

for_loop_declaration: declare_assign_single;

for_loop_assignment:
        ID ASSIGN expr -> ^( FOR_LOOP_ASSIGN ID expr )
    ;

iterate_loop:
        ITERATE v=ID b=block UNTIL LPAREN e=expr RPAREN
                -> ^( ITERATE $v $b $e )
    ;
wait_stmt:
        WAIT a=expr_argument_list b=block
            -> ^( WAIT_STATEMENT $a $b)
    ;

declaration_multi:
        type=ID declare_rest declare_rest_more*
            -> ^( DECLARATION $type declare_rest
                                                declare_rest_more* )
    ;

declare_rest_more:
        COMMA declare_rest -> declare_rest
    ;

// Single variable declaration with assignment
// keep same AST structure
declare_assign_single:
        type=ID v=ID array_marker* mapping? ASSIGN expr
            -> ^( DECLARATION $type
                  ^( DECLARE_ASSIGN
                    ^( DECLARE_VARIABLE_REST $v array_marker*
                             mapping?) expr))
    ;

declare_rest:
    v=ID array_marker* mapping? (
          /* empty */ ->  ^( DECLARE_VARIABLE_REST $v array_marker*
                             mapping?)
       |  ASSIGN expr ->  ^( DECLARE_ASSIGN
           ^( DECLARE_VARIABLE_REST $v array_marker* mapping? ) expr))
    ;

array_marker:
        LSQUARE RSQUARE -> ARRAY
    ;

mapping:
    LT s=expr GT
        -> ^( MAPPING $s )
    ;

expr: orexpr;


/* handling precedence with technique from
 * http://www.antlr.org/wiki/display/ANTLR3/Tree+construction
 */
orexpr:
        (andexpr->andexpr)
        (     OR b=andexpr
            -> ^(OPERATOR OR $orexpr $b)
        )*
    ;

andexpr:
        (eqexpr->eqexpr)
        (     AND b=eqexpr
            -> ^(OPERATOR AND $andexpr $b)
        )*
    ;

eqexpr:
        (cmpexpr->cmpexpr)
        (     eqexpr_op b=cmpexpr
            -> ^(OPERATOR eqexpr_op $eqexpr $b)
        )*
    ;
eqexpr_op : EQUALS|NEQUALS
    ;

cmpexpr:
        (aexpr->aexpr)
        (     cmpexpr_op b=aexpr
            -> ^(OPERATOR cmpexpr_op $cmpexpr $b)
        )*
    ;
cmpexpr_op: LT|LTE|GT|GTE
    ;

aexpr:
        (mexpr->mexpr)
        (     aexpr_op b=mexpr
            -> ^(OPERATOR aexpr_op $aexpr $b)
        )*
    ;

aexpr_op: PLUS | MINUS
    ;

mexpr:
        (powexpr->powexpr)
        (     mexpr_op e=powexpr
            -> ^(OPERATOR mexpr_op $mexpr $e)
        )*
    ;

mexpr_op: MULT | DIV | INTDIV | MOD
    ;


powexpr:
        (uexpr->uexpr)
        (     POW e=uexpr
            -> ^(OPERATOR POW $powexpr $e)
        )*
    ;

// Unary expression
uexpr:
        pfexpr
    |   uexpr_op uexpr -> ^( OPERATOR uexpr_op uexpr )
    ;

uexpr_op: NOT
    | MINUS -> NEGATE
    ;

// postfix expression
pfexpr:
        (base_expr->base_expr)
        (   array_index -> ^(ARRAY_LOAD $pfexpr array_index )
          | id_subscript -> ^(STRUCT_LOAD $pfexpr id_subscript )
        )*
    ;

array_index:
        LSQUARE expr RSQUARE -> expr
    ;

id_subscript:
        '.' ID -> ID
    ;

base_expr:
            literal
        |   function_call
        |   variable
        |    LPAREN e=expr RPAREN
            -> $e
        |   array_constructor
    ;

literal:
        n=INTEGER -> ^( INT_LITERAL $n )
            |   d=(DECIMAL | SCI_DECIMAL | INFINITY | NOTANUMBER)
                 -> ^( FLOAT_LITERAL $d)
            |   s=STRING -> ^( STRING_LITERAL $s)
            |   s=STRING_MULTI_LINE_1 -> ^( STRING_LITERAL $s)
            |   s=STRING_MULTI_LINE_2 -> ^( STRING_LITERAL $s)
            |   b=bool_lit -> ^( BOOL_LITERAL $b)
    ;


variable:
        ID -> ^( VARIABLE ID )
    ;
bool_lit: TRUE | FALSE
    ;

function_call:
         call_annotation* f=function_call_name a=expr_argument_list -> ^( CALL_FUNCTION $f $a call_annotation*)
    ;

function_call_name:
         ID
    |    ATSIGN ID -> ^( DEPRECATED ID )
    ;

call_annotation:
		ATSIGN ann=ID ASSIGN e=expr
			-> ^( CALL_ANNOTATION $ann $e )
	;

expr_argument_list:
        LPAREN expr_arguments? RPAREN -> ^( ARGUMENT_LIST expr_arguments? )
    ;

expr_arguments:
        expr expr_arguments_rest*
    ;

expr_arguments_rest: COMMA expr -> expr
    ;


// Handle the [1:2] range operator, and the explicit array construction
//  e.g. [1,2,3,4]
array_constructor:
        LSQUARE (
          RSQUARE
             -> ^( ARRAY_ELEMS )
        | e1=expr (
                COLON e2=expr array_range_more* RSQUARE
                    -> ^( ARRAY_RANGE $e1 $e2 array_range_more* )
            |   array_elems_more* RSQUARE
                    -> ^( ARRAY_ELEMS $e1 array_elems_more* )))
    ;

array_range_more:
        COLON expr -> expr
    ;

array_elems_more:
        COMMA expr -> expr
    ;


assignment_expr:
        i=assignment_list ASSIGN e=expr more_expr* ->
        ^( ASSIGN_EXPRESSION $i $e more_expr* )
    ;

more_expr:
        COMMA expr -> expr
    ;

assignment_list:
        LPAREN a=assignment_list_arguments RPAREN ->
            ^( IDENTIFIER_LIST $a )
        |    a=assignment_list_arguments ->
            ^( IDENTIFIER_LIST $a )
    ;

assignment_list_arguments:
        /* always must be at least one identifier */
        assign_target assignment_list_arguments_rest*
    ;

assignment_list_arguments_rest: COMMA assign_target -> assign_target
    ;

assign_target:
        ID assign_path_element* ->
            ^( ASSIGN_TARGET ^( VARIABLE ID ) assign_path_element* )
    ;

assign_path_element:
        id_subscript -> ^( STRUCT_PATH id_subscript)
    |   array_index   -> ^( ARRAY_PATH  array_index)
    ;

// only allow function calls as non-assignment statements
expr_stmt: e=function_call -> ^( EXPR_STMT $e )
    |      e=variable -> ^( EXPR_STMT $e )
    ;

update_stmt: v=ID LT cmd=ID GT MUTATE expr SEMICOLON
               -> ^( UPDATE $cmd $v expr)
    ;

annotation:
        ATSIGN a=ID
            -> ^( ANNOTATION $a )
    |   ATSIGN a=ID ASSIGN annotation_val
            -> ^( ANNOTATION $a annotation_val )
    ;

annotation_val: ID | INTEGER
    ;

// Handle C preprocessor lines in lexer as they can be inserted
// at random lines in Swift source
CPP_LINE: HASH (~('\n'))* (('\n'))
            { $channel = CPP; }
        ;

// Single-line comments, C/C++ style
SINGLE_LINE_COMMENT_C
    :    '//' (~('\n'))* (('\n'))
        { $channel = HIDDEN; }
    ;

// Multi-line comments, C/C++ style
MULTI_LINE_COMMENT
    :   '/*' ( options {greedy=false;} : . )* '*/' {$channel=HIDDEN;}
    ;

// LEXER RULES



// Tokens that are actually in the SwiftScript
// (reserved words)
APP:  'app'  ;
BUILTIN:  'builtin'  ;
IF:   'if';
ELSE: 'else';
SWITCH: 'switch';
CASE: 'case';
DEFAULT: 'default';
FOREACH: 'foreach';
IN: 'in';
FOR: 'for';
ITERATE: 'iterate';
UNTIL: 'until';
WAIT: 'wait';
TRUE: 'true';
FALSE: 'false';
GLOBAL: 'global';
CONST: 'const';
TYPE:  'type';
TYPEDEF:  'typedef';
IMPORT: 'import';

STDIN: 'stdin';
STDOUT: 'stdout';
STDERR: 'stderr';


// Numeric building blocks
fragment
NUM_FRAG: (DIGIT)+ ;

fragment
DEC_FRAG: NUM_FRAG '.' NUM_FRAG;

// Number tokens
INTEGER: NUM_FRAG;
DECIMAL: DEC_FRAG;
SCI_DECIMAL: NUM_FRAG ('.' NUM_FRAG)? ('e'|'E') '-'? NUM_FRAG;
NOTANUMBER: 'NaN';
INFINITY: 'inf';

ID: (ALPHA|UNDER)(ALPHA|UNDER|DIGIT)*;

LPAREN:    '(' ;
RPAREN:    ')' ;
LBRACE:    '{' ;
RBRACE:    '}' ;
LSQUARE:   '[' ;
RSQUARE:   ']' ;

COMMA:     ',' ;
HASH:      '#';
SEMICOLON: ';';
COLON: ':';
ATSIGN: '@';
VARARGS: '...';
PIPE: '|';

WHITESPACE :
        ( '\t' | ' ' | '\n' | '\r' | '\u000C' )+
        { $channel = HIDDEN; }
    ;

fragment DIGIT  : '0'..'9';
fragment ALPHA  : 'a'..'z' | 'A'..'Z';
fragment UNDER  : '_';

// individual characters
fragment
CHAR : ESCAPE_CODE | ~('\\'|'"');

fragment
ESCAPE_CODE:
        '\\' ('a'|'b'|'f'|'n'|'r'|'t'|'v'|'\''|'"'|'\\'|'\?')
    | '\\' '0'..'7'+ // octal escape
    | '\\' 'x' (DIGIT|'a'..'f'|'A'..'F')+ // hex escape
    ;

// String literal with c-style escape sequences
STRING: '"' CHAR* '"';

// Asciidoc-style multi-line string
STRING_MULTI_LINE_1
    :   '----\n' ( options {greedy=false;} : . )* '----'
    ;

// Python-style multi-line string
STRING_MULTI_LINE_2
    :   '"""\n' ( options {greedy=false;} : . )* '"""'
    ;
