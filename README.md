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

## test parser from within javascript code via commonjs:

```
// test.js
var parser = require("./ansic").parser

console.log(
    JSON.stringify(
        parser.parse("int main() { x = 25+x; } "),
        null, 
        2
    )
)
```

## test parser from within javascript code via import:

```
// test.mjs
import * as parser from "./ansic.js"

console.log(
    JSON.stringify(
        parser.parse("int main() { x = 25+x; } "),
        null, 
        2
    )
)
```


# Program Analysis:

We have added a frontend to perform abstract interpretation based static
program analysis via the simple Python script ```analyzeANSI.py``` - in 
It comes with a predefined output to graphviz in dot format, as well as with
a few example constraint systems that are generated when the program is started
with particular parameters.

A start point into setting up custom constraints for a static analysis
via abstract interpretation can be to provide a new edge collector for 
the ```iterateEdges``` and write out constraints for a fixpoint solver.

```
./analyzeANSI.py [input.c] | xdot /dev/stdin
```