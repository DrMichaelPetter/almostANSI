# npm install jison
jison="node node_modules/jison/lib/cli.js"
$jison ansic.jison ansic.jisonlex
echo "compilation done; run with:     node ansic.js test.c"