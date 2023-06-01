%lex
digit                       [0-9]
id                          [a-zA-Z][a-zA-Z0-9]*
hex		                	[a-fA-F0-9]
exponent                	[Ee][+-]?{digit}+
floatsuffix		            [fFlL]
intsuffix                	[uUlL]*

%options flex

%%
"//".*                      /* ignore comment */
"typedef"                    return 'TYPEDEF';
"extern"                     return 'EXTERN';
"static"                     return 'STATIC';
"auto"                       return 'AUTO';
"register"                   return 'REGISTER';
"char"                       return 'CHAR';
"short"                      return 'SHORT';
"int"                        return 'INT';
"long"                       return 'LONG';
"signed"                     return 'SIGNED';
"unsigned"                   return 'UNSIGNED';
"float"                      return 'FLOAT';
"double"                     return 'DOUBLE';
"const"                      return 'CONST';
"volatile"                   return 'VOLATILE';
"void"                       return 'VOID';
"struct"                     return 'STRUCT';
"union"                      return 'UNION';
"enum"                       return 'ENUM';
"case"                       return 'CASE';
"default"                    return 'DEFAULT';
"if"                         return 'IF';
"else"                       return 'ELSE';
"switch"                     return 'SWITCH';
"while"                      return 'WHILE';
"do"                         return 'DO';
"for"                        return 'FOR';
"goto"                       return 'GOTO';
"continue"                   return 'CONTINUE';
"break"                      return 'BREAK';
"return"                     return 'RETURN';
"sizeof"                     return 'SIZEOF';
"..."                        return 'ELLIPSIS';

L\'(\\.|[^\\\'])+\'         %{ yytext = yytext.substr(2,yyleng-2); return 'CONSTANT'; %}
\'(\\.|[^\\\'])+\'          %{ yytext = yytext.substr(1,yyleng-2); return 'CONSTANT'; %}

L\"(\\.|[^\\\"])*\" 		%{ yytext = yytext.substr(2,yyleng-2); return 'STRING_LITERAL'; %}
\"(\\.|[^\\\"])*\" 		    %{ yytext = yytext.substr(1,yyleng-2); return 'STRING_LITERAL'; %}

0[xX]{hex}+{intsuffix}?		                        return 'CONSTANT';
0{digit}+{intsuffix}?		                        return 'CONSTANT';
{digit}+{intsuffix}?		                        return 'CONSTANT';

{digit}+{exponent}{floatsuffix}?		            return 'CONSTANT';
{digit}*"."{digit}+({exponent})?{floatsuffix}?	    return 'CONSTANT';
{digit}+"."{digit}*({exponent})?{floatsuffix}?	    return 'CONSTANT';


{id}                         %{
                                if (parser.yy.typenames.includes(yytext))
                                    return 'TYPE_NAME';
                                return 'IDENTIFIER';
                             %}

"->"                        return 'PTR_OP';
"++"                        return 'INC_OP';
"--"                        return 'DEC_OP';
"<<"                        return 'LEFT_OP';
">>"                        return 'RIGHT_OP';
"<="                        return 'LE_OP';
">="                        return 'GE_OP';
"=="                        return 'EQ_OP';
"!="                        return 'NE_OP';
"&&"                        return 'AND_OP';
"||"                        return 'OR_OP';
"*="                        return 'MUL_ASSIGN';
"/="                        return 'DIV_ASSIGN';
"%="                        return 'MOD_ASSIGN';
"+="                        return 'ADD_ASSIGN';
"-="                        return 'SUB_ASSIGN';
"<<="                       return 'LEFT_ASSIGN';
">>="                       return 'RIGHT_ASSIGN';
"&="                        return 'AND_ASSIGN';
"^="                        return 'XOR_ASSIGN';
"|="                        return 'OR_ASSIGN';
";"                         return ';';
"<"                         return '<';
">"                         return '>';
"*"                         return '*';
"/"                         return '/';
"+"                         return '+';
"-"                         return '-';
"%"                         return '%';
"="                         return '=';
","                         return ',';
"."                         return '.';
":"                         return ':';
"&"                         return '&';
"|"                         return '|';
"~"                         return '~';
"^"                         return '^';
"?"                         return '?';
"!"                         return '!';
"["                         return '[';
"]"                         return ']';
"("                         return '(';
")"                         return ')';
"{"                         return '{';
"}"                         return '}';

\s+                         /* skip whitespace */
//"."                         throw 'Illegal character';
<<EOF>>                     return 'EOF';