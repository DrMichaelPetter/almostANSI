// --------------------------------------------------
//	C-Parser for simplistic C Programs:
//  mostly does the job, except for:
//   - uses of tagged structs, enums and unions are not checked against declarations of the same tag
//   - multiple uses of tagnames for structs, enums, unions etc. is not checked for
//   - enum values are neither tracked in the environment, nor is their value determined in any way
//   - struct bit-fields
//   - type qualifiers (volatile / const)
//   - K&R legacy function declaration
// --------------------------------------------------


%token IDENTIFIER CONSTANT STRING_LITERAL SIZEOF
%token PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token XOR_ASSIGN OR_ASSIGN TYPE_NAME

%token TYPEDEF EXTERN STATIC AUTO REGISTER
%token CHAR SHORT INT LONG SIGNED UNSIGNED FLOAT DOUBLE CONST VOLATILE VOID
%token STRUCT UNION ENUM ELLIPSIS EOF

%token CASE DEFAULT IF ELSE SWITCH WHILE DO FOR GOTO CONTINUE BREAK RETURN

%nonassoc IF_WITHOUT_ELSE
%nonassoc ELSE

%{
	parser.yy.typenames=[] // access current typenames
	parser.yy.scopes=[parser.yy.typenames]    // manage scoped typenames in a stack, pushing copies of old scopes when entering, and popping on leaving
	function newScope(){
		parser.yy.typenames=[...parser.yy.typenames]
		parser.yy.scopes.push(parser.yy.typenames)
	}
	function deleteScope(){
		parser.yy.scopes.pop()
		parser.yy.typenames=parser.yy.scopes.slice(-1)
	}

	function printtree(t){
		 console.log(JSON.stringify(t,null,2))
	}
	function identifier(name){
		return { type:"identifier", name:name }
	}
	function pointerto(n,t){
		let ret = t
		for (let i = 1; i <= n; i++) {
  			ret = { type: "pointer", base: ret}
		} 
		return ret
	}
	function arrayof(t){
		return { kind: "type", type: "array", base: t}
	}
	function functionof(t,parameters){
		return { kind: "type", type: "function", base: t, params: parameters }
	}
	function structof(kind, tagname, content){
		return  { kind: "type", type: kind, tagname: tagname, body: content }
	}
	function basetypefor(t,b,loc){
		if (b.includes("typedef")) {
			const temp=[...b]
			temp.splice(temp.indexOf("typedef"),1)
			return { kind: "type", type: "typedef", loc: loc,base: temp, declarator: t }
		}
		return { kind: "type", type: "declaration", loc: loc,base: b, declarator: t }
	}
	function abstracttype(){
		return { kind: "type", type:"typeplaceholder" }
	}
	function refreshTypenames(b,declarations){
		if (b.includes("typedef")) {
			for (declaration of declarations){
				let t=declaration.declarator
				while(t.type!="identifier"){
					t=t.base
				}
				parser.yy.typenames.push(t.name)
			}
		}
	}
	function binaryexpr(l,op,r,loc){
		return { kind: "expr", loc: loc, left: l, operator:op, right: r}
	}
	function ternaryexpr(l,mid,r,loc){
		return { kind: "expr", loc: loc, cond: l, condtrue:mid, condfalse: r}
	}
	function unaryexpr(e,op,loc){
		return { kind: "expr", loc: loc, operator:op, child: e}
	}
	function environment(decls){
		let decl = {}
		let tn = {}
		let tags = {}
		for (declaration of decls){
			if (declaration.declarator.type != "typeplaceholder"){
				let name=findAndResetName(declaration)
				decl[name]=declaration
				if (declaration.type==="typedef")       tn[name]=declaration
				if (declaration.type==="declaration") decl[name]=declaration
			}
			for (base of declaration.base) {
				if (typeof base==='object') {
					if (base.type==="struct")
						tags[base.tagname]=base
					if (base.type==="union")
						tags[base.tagname]=base
					if (base.type==="enum")
						tags[base.tagname]=base
				}
			}
		}
		return { declarations:decl , typenames: tn, structtags: tags }
	}
	function findAndResetName(decl){
		let t=decl.declarator
		let told=t
		while(t.type!="identifier"){
			told=t
			t=t.base
			if (t.type==="typeplaceholder") return null;
		}
		let name = t.name
		told.base=abstracttype()
		return name
	}
	function attachLoc(smthg,loc){
		smthg.loc=loc
		return smthg
	}
	function enumfrom(name,keyvals,loc){
		let rep = {}
		if (keyvals!=null)
		{
			keystore = { }
			for (keyval of keyvals) {
				keystore[keyval.key]=keyval.value
			}
			rep = { kind: "type", loc:loc, type: "enum", tagname:name, enumvalues:keystore }
		}
		rep = { kind: "type", loc:loc, type: "enum", tagname:name }
		return rep
	}
%}

%start translation_unit
%%

primary_expression
	: IDENTIFIER
	| CONSTANT
	| STRING_LITERAL
	| '(' expression ')' 										-> $2
	;

postfix_expression
	: primary_expression 										-> $1
	| postfix_expression '[' expression ']'						-> binaryexpr($1,$2,$3,@$)
	| postfix_expression '(' ')'								-> binaryexpr($1,$2,[],@$)
	| postfix_expression '(' argument_expression_list ')'		-> binaryexpr($1,$2,$3,@$)
	| postfix_expression '.' IDENTIFIER							-> binaryexpr($1,$2,$3,@$)
	| postfix_expression PTR_OP IDENTIFIER						-> binaryexpr($1,$2,$3,@$)
	| postfix_expression INC_OP									-> unaryexpr($1,String($2)+'post',@$)
	| postfix_expression DEC_OP									-> unaryexpr($1,String($2)+'post',@$)
	;

argument_expression_list
	: assignment_expression										->[$1]
	| argument_expression_list ',' assignment_expression		{ $$=[...$1];$$.push($3); }
	;

unary_expression
	: postfix_expression 										-> $1
	| INC_OP unary_expression									-> unaryexpr($2,$1,@$)						
	| DEC_OP unary_expression									-> unaryexpr($2,$1,@$)
	| unary_operator cast_expression							-> unaryexpr($2,$1,@$)
	| SIZEOF unary_expression									-> unaryexpr($2,$1,@$)
	| SIZEOF '(' type_name ')'									-> unaryexpr($3,$1,@$)
	;

unary_operator
	: '&'
	| '*'
	| '+'
	| '-'
	| '~'
	| '!'
	;

cast_expression
	: unary_expression 										-> $1
	| '(' type_name ')' cast_expression						-> binaryexpr($2,'typecast',$4,@$)
	;

multiplicative_expression
	: cast_expression 										-> $1
	| multiplicative_expression '*' cast_expression			-> binaryexpr($1,$2,$3,@$)
	| multiplicative_expression '/' cast_expression			-> binaryexpr($1,$2,$3,@$)
	| multiplicative_expression '%' cast_expression			-> binaryexpr($1,$2,$3,@$)
	;

additive_expression
	: multiplicative_expression 										-> $1
	| additive_expression '+' multiplicative_expression			-> binaryexpr($1,$2,$3,@$)
	| additive_expression '-' multiplicative_expression			-> binaryexpr($1,$2,$3,@$)
	;

shift_expression
	: additive_expression 										-> $1
	| shift_expression LEFT_OP additive_expression				-> binaryexpr($1,$2,$3,@$)
	| shift_expression RIGHT_OP additive_expression				-> binaryexpr($1,$2,$3,@$)
	;

relational_expression
	: shift_expression 										-> $1
	| relational_expression '<' shift_expression			-> binaryexpr($1,$2,$3,@$)
	| relational_expression '>' shift_expression			-> binaryexpr($1,$2,$3,@$)
	| relational_expression LE_OP shift_expression			-> binaryexpr($1,$2,$3,@$)
	| relational_expression GE_OP shift_expression			-> binaryexpr($1,$2,$3,@$)
	;

equality_expression
	: relational_expression 										-> $1
	| equality_expression EQ_OP relational_expression				-> binaryexpr($1,$2,$3,@$)
	| equality_expression NE_OP relational_expression				-> binaryexpr($1,$2,$3,@$)
	;

and_expression
	: equality_expression 										-> $1
	| and_expression '&' equality_expression					-> binaryexpr($1,$2,$3,@$)
	;

exclusive_or_expression
	: and_expression 										-> $1
	| exclusive_or_expression '^' and_expression			-> binaryexpr($1,$2,$3,@$)
	;

inclusive_or_expression
	: exclusive_or_expression 										-> $1
	| inclusive_or_expression '|' exclusive_or_expression			-> binaryexpr($1,$2,$3,@$)
	;

logical_and_expression
	: inclusive_or_expression 										-> $1
	| logical_and_expression AND_OP inclusive_or_expression			-> binaryexpr($1,$2,$3,@$)
	;

logical_or_expression
	: logical_and_expression 										-> $1
	| logical_or_expression OR_OP logical_and_expression			-> binaryexpr($1,$2,$3,@$)
	;

conditional_expression
	: logical_or_expression 										  -> $1
	| logical_or_expression '?' expression ':' conditional_expression -> ternaryexpr($1,$3,$5,@$)
	;

assignment_expression
	: conditional_expression 										-> $1
	| unary_expression assignment_operator assignment_expression	-> binaryexpr($1,$2,$3,@$)
	;

assignment_operator
	: '='
	| MUL_ASSIGN
	| DIV_ASSIGN
	| MOD_ASSIGN
	| ADD_ASSIGN
	| SUB_ASSIGN
	| LEFT_ASSIGN
	| RIGHT_ASSIGN
	| AND_ASSIGN
	| XOR_ASSIGN
	| OR_ASSIGN
	;

expression
	: assignment_expression					-> $1
	| expression ',' assignment_expression  -> binaryexpr($1,$2,$3,@$) 
	;

constant_expression
	: conditional_expression					-> $1
	;

declaration
	: partial_declaration ';' 							-> $1
	;

partial_declaration
	: declaration_specifiers 							-> [basetypefor(abstracttype(),$1,@$)]    // -> introduces nametags for struct, union or enum
	| declaration_specifiers init_declarator_list       {  $$ = []; for (const declarator of $2) { $$.push(basetypefor(declarator,$1,@$)); }; refreshTypenames($1,$$); }
	;

declaration_specifiers
	: storage_class_specifier 							-> [$1] 
	| storage_class_specifier declaration_specifiers 	{ $$=[...$2]; $$.push($1); }
	| type_specifier 									-> [$1]
	| type_specifier declaration_specifiers 			{ $$=[...$2]; $$.push($1); }
//	| type_qualifier 									-> [] // const volatile -> ignore
//	| type_qualifier declaration_specifiers 			-> $2
	;

init_declarator_list
	: init_declarator 						   			-> [$1]
	| init_declarator_list ',' init_declarator 			{ $$ = [...$1]; $$.push($3); }
	;

init_declarator
	: declarator 				 						-> $1
	| declarator '=' initializer 						{ $$ = $1; $$.initializer=$3; } 
	;

storage_class_specifier
	: TYPEDEF
	| EXTERN
	| STATIC
	| AUTO
	| REGISTER
	;

type_specifier
	: VOID
	| CHAR
	| SHORT
	| INT
	| LONG
	| FLOAT
	| DOUBLE
	| SIGNED
	| UNSIGNED
	| struct_or_union_specifier { $$=$1; }
	| enum_specifier
	| TYPE_NAME
	;

struct_or_union_specifier
	: struct_or_union IDENTIFIER '{' struct_declaration_list '}' -> structof($1,$2,$4)
	| struct_or_union TYPE_NAME '{' struct_declaration_list '}'  -> structof($1,$2,$4)
	| struct_or_union '{' struct_declaration_list '}' 			 -> structof($1,null,$3)
	| struct_or_union IDENTIFIER 								 -> structof($1,$2,null)
	| struct_or_union TYPE_NAME 								 -> structof($1,$2,null)
	;

struct_or_union
	: STRUCT
	| UNION 
	;

struct_declaration_list
	: struct_declaration 								-> [$1]
	| struct_declaration_list struct_declaration 		{ $$=[...$1];$$.push($2); } 
	;

struct_declaration
	: specifier_qualifier_list struct_declarator_list ';' -> basetypefor($2,$1,@$)
	;

specifier_qualifier_list
	: type_specifier specifier_qualifier_list  	{ $$=[...$2]; $$.push($1); }
	| type_specifier 						  	-> [$1]
//	| type_qualifier specifier_qualifier_list 	-> $2
//	| type_qualifier 						  	-> [] // const volatile -> ignore
	;

struct_declarator_list
	: struct_declarator 						   -> [$1]
	| struct_declarator_list ',' struct_declarator { $$ = [...$1]; $$.push($3); }
	;

struct_declarator
	: declarator 						 -> $1
//	| ':' constant_expression 				 // alignment is stupid; -> ignore
//	| declarator ':' constant_expression -> $1
	;

enum_specifier
	: ENUM '{' enumerator_list '}'            -> enumfrom(null,$3,@$)
	| ENUM IDENTIFIER '{' enumerator_list '}' -> enumfrom($2,$4,@$)
	| ENUM IDENTIFIER                         -> enumfrom($2,null,@$)
	| ENUM TYPE_NAME '{' enumerator_list '}' -> enumfrom($2,$4,@$)
	| ENUM TYPE_NAME                         -> enumfrom($2,null,@$)
	;

enumerator_list
	: enumerator                          -> [$1]
	| enumerator_list ',' enumerator      {$$=[...$1];$$.push($3); }
	;

enumerator
	: IDENTIFIER                         -> { key: $1, value: null }
	| IDENTIFIER '=' constant_expression -> { key: $1, value: $3 }
	;

// type_qualifier
// 	: CONST
// 	| VOLATILE
// 	;

declarator
	: pointer direct_declarator 			-> pointerto($1,$2)
	| direct_declarator 					-> $1
	;

direct_declarator
	: IDENTIFIER 										-> identifier(yytext)
	| '(' declarator ')' 								-> $2
	| direct_declarator '[' constant_expression ']'  	-> arrayof($1)
	| direct_declarator '[' ']' 						-> arrayof($1)
	| direct_declarator '(' parameter_type_list ')' 	-> functionof($1, $3 )
//	| direct_declarator '(' identifier_list ')' 		-> functionof($1, { } ) // this is real stupid -> ignore
	| direct_declarator '(' ')' 						-> functionof($1, { } )
	;

pointer
	: '*' 								-> 1
//	| '*' type_qualifier_list 			-> 1
	| '*' pointer 						-> 1 + $2
//	| '*' type_qualifier_list pointer 	-> 1 + $3
	;

// type_qualifier_list
// 	: type_qualifier
// 	| type_qualifier_list type_qualifier
// 	;


parameter_type_list
	: parameter_list 								-> $1
	| parameter_list ',' ELLIPSIS 					{ $$=[...$1];$$.push($3); } 
	;

parameter_list
	: parameter_declaration 				   		-> [$1]
	| parameter_list ',' parameter_declaration 		{ $$=[...$1];$$.push($3); }
	;

parameter_declaration
	: declaration_specifiers declarator 			-> basetypefor($2,$1,@$)
	| declaration_specifiers abstract_declarator	-> basetypefor($2,$1,@$)
	| declaration_specifiers 						-> basetypefor(abstracttype(),$1,@$)
	;

// identifier_lists for legacy function declarations: -> ignored
// identifier_list
// 	: IDENTIFIER
// 	| identifier_list ',' IDENTIFIER
// 	;

type_name
	: specifier_qualifier_list                       	-> basetypefor(abstracttype(),$1,@$)
	| specifier_qualifier_list abstract_declarator		-> basetypefor($2,$1,@$)
	;

abstract_declarator
	: pointer 							 				-> pointerto($1,abstracttype())
	| direct_abstract_declarator		 				-> $1
	| pointer direct_abstract_declarator 				-> pointerto($1,$2)
	;

direct_abstract_declarator
	: '(' abstract_declarator ')' 								-> $2
	| '[' ']' 													-> arrayof(abstracttype())
	| '[' constant_expression ']' 								-> arrayof(abstracttype())
	| direct_abstract_declarator '[' ']' 						-> arrayof($1)
	| direct_abstract_declarator '[' constant_expression ']' 	-> arrayof($1)
	| '(' ')' 													-> functionof(abstracttype(), { } )
	| '(' parameter_type_list ')' 								-> functionof(abstracttype(), $2 )
	| direct_abstract_declarator '(' ')'  						-> functionof($1, { } )
	| direct_abstract_declarator '(' parameter_type_list ')'	-> functionof($1, $3 )
	;

initializer
	: assignment_expression        -> $1
 	| '{' initializer_list '}'     -> { kind: "arrayinitializer", values:$2 }
 	| '{' initializer_list ',' '}' -> { kind: "arrayinitializer", values:$2 }
 	;
 
initializer_list
 	: initializer							-> [$1]
 	| initializer_list ',' initializer      { $$=[...$1]; $$.push($3); }
 	;

statement
	: labeled_statement 			-> attachLoc($1,@$) 
	| compound_statement 			-> attachLoc($1,@$) // done apart from decls
	| expression_statement 			-> attachLoc($1,@$) 
	| selection_statement 			-> attachLoc($1,@$)
	| iteration_statement 			-> attachLoc($1,@$)
	| jump_statement 				-> attachLoc($1,@$) 
	;

labeled_statement
	: IDENTIFIER ':' statement                { $$=$3; $$.label=$1; }
	| CASE constant_expression ':' statement  { $$=$4; $$.caselabel=$2; }
	| DEFAULT ':' statement					  { $$=$3; $$.caselabel='default'; }
	;

compound_statement
	: partial_compound_statement '}' 								-> $1
	;

partial_compound_statement
	: partial2_compound_statement				 	              { deleteScope(); $$={  kind: "stmt", type: "block", declarations:[], code: [] }; }
	| partial2_compound_statement statement_list 	              { deleteScope(); $$={  kind: "stmt", type: "block", declarations:[], code: [...$2]}; }
	| partial2_compound_statement declaration_list                { deleteScope(); $$={  kind: "stmt", type: "block", declarations:$2, code: [] }; }
	| partial2_compound_statement declaration_list statement_list { deleteScope(); $$={  kind: "stmt", type: "block", declarations:$2, code:[...$3] };  }
	;

partial2_compound_statement
	: '{' { newScope() }
	;

declaration_list
	: declaration											-> [$1]
	| declaration_list declaration							{ $$=[...$1];$$.push($2); }
	;

statement_list
	: statement               								-> [$1]
	| statement_list statement								{ $$=[...$1]; $$.push($2); }
	;

expression_statement
	: ';'
	| expression ';' 											-> { kind: 'stmt', type: 'expr', expr: $1}
	;

selection_statement
	: IF '(' expression ')' statement %prec IF_WITHOUT_ELSE		-> { kind:'stmt', type:'if', cond: $3, stmt: $5, } 
	| IF '(' expression ')' statement ELSE statement			-> { kind:'stmt', type:'if', cond: $3, stmt: $5, else: $7 }
	| SWITCH '(' expression ')' statement						-> { kind:'stmt', type:'switch', cond: $3, stmt: $5, }
	;

iteration_statement
	: WHILE '(' expression ')' statement												-> {kind: 'stmt', type: 'while' , cond: $3, stmt: $5 }
	| DO statement WHILE '(' expression ')' ';'											-> {kind: 'stmt', type: 'do'    , cond: $5, stmt: $2 }
	| FOR '(' expression_statement expression_statement ')' statement					-> {kind: 'stmt', type: 'for'   , e1: $3, e2: $4, stmt: $6 }
	| FOR '(' expression_statement expression_statement expression ')' statement		-> {kind: 'stmt', type: 'for'   , e1: $3, e2: $4, e3: $5, stmt: $7 }
	;

jump_statement
	: GOTO IDENTIFIER ';'				-> { kind: 'stmt', type: 'goto', where: $2 }
	| CONTINUE ';'						-> { kind: 'stmt', type: 'continue' }
	| BREAK ';'							-> { kind: 'stmt', type: 'break' }
	| RETURN ';'						-> { kind: 'stmt', type: 'return' }
	| RETURN expression ';'				-> { kind: 'stmt', type: 'return', expr: $2 }
	;

translation_unit 
	: external_declaration 						{ $$=[...$1]; }
	| external_declaration EOF					{ $$=[...$1]; return $$; }
	| translation_unit external_declaration 	{ $$=[...$1].concat($2); }
	| translation_unit external_declaration EOF { $$=[...$1].concat($2); return $$; }
	;

external_declaration
	: function_definition				-> $1
	| declaration 						-> $1
	;

function_definition
	: declaration_specifiers declarator compound_statement { $$=basetypefor($2,$1,@$);$$.body=$3;$$=[$$]; }
//  | declaration_specifiers declarator declaration_list compound_statement  // declaration_list based function declarations are one of the most stupid things on earth -> ignore
//	| declarator declaration_list compound_statement
//	| declarator compound_statement // don't even ask me what the purpose of this one is... -> ignore
	;
