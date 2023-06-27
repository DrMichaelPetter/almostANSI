# almostANSI
lightweight almost ANSI C Parser for javascript in jison. Parses plain C (no preprocessor, just C) source files and returns a javascript-object based
representation of its AST with location information.

### what's missing ('cause it's too good to be true for 3 days of work):
- error recovery
- general robustness against malicious C programming habits :-)
- uses of tagged structs, enums and unions are not checked against declarations of the same tag
- multiple uses of tagnames for structs, enums, unions is not prohibited
- enum values are neither tracked in the environment, nor is their value determined in any way
- struct bit-fields is not supported ( ``` struct foo { int bar:5, baz:13; }``` )
- type qualifiers (volatile / const)
- legacy K&R function declarations ( ```int f(a,b) int a; double b; {}``` )

## see a demonstration of the code in action:

We have a small [HTML-demonstrator](https://github.com/DrMichaelPetter/almostANSI/blob/main/demo/index.html) running [here](https://drmichaelpetter.github.io/almostANSI)


## install dependencies & generate parser:

To generate the parser, execute the following piece once:

```
npm install jison 
node node_modules/jison/lib/cli.js  ansic.jison ansic.jisonlex 
```
The resulting ```ansic.js``` is now a standalone javascript file, that can be used without any dependencies.

## test parser CLI (will usually only output errors on faulty input):

``` node ansic.js test.c ```

## test parser from within javascript code:

```
var parser = require("./ansic").parser

console.log(
    JSON.stringify(
        parser.parse("int main() { x = 25+x; } "),
        null, 
        2
    )
)
```

## newest addition:

creating a control flow graph from an input file can be achieved via a
simple Python script - in the default case, we do that for the main
function. A start point into setting up constraints for a static analysis
via abstract interpretation can be to process the edges in the ```edgekeeper```
array and write out constraints for a fixpoint solver.

```
./analyzeANSI.py [input.c] | xdot /dev/stdin
```