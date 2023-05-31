# almostANSI
lightweight almost ANSI C Parser for javascript in jison.

### what's missing ('cause it's too good to be true):
- uses of tagged structs, enums and unions are not checked against declarations of the same tag
- multiple uses of tagnames for structs, enums, unions is not prohibited
- enum values are neither tracked in the environment, nor is their value determined in any way
- struct bit-fields is not supported ( ``` struct foo { int bar:5, baz:13; }``` )
- type qualifiers (volatile / const)
- legacy K&R function declarations ( ```int f(a,b) int a; double b; {}``` )

## install dependencies:

``` npm install jison ```

## run parsergen:

``` node node_modules/jison/lib/cli.js  ansic.jison ansic.jisonlex ```

## test compiler CLI:

``` node ansic.js test.c ```

## test compiler as library:

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
