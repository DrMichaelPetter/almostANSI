#!/usr/bin/python3
import subprocess
import json
import sys
import functools

def printjson(jso):
    print(json.dumps(jso,indent=2))

def parseANSIC(inputfile):
    p = subprocess.Popen(['nodejs',
                "-e",
                "console.log(JSON.stringify(require(\"./ansic.js\").parser.parse(require('fs').readFileSync(require('path').normalize(\""+
                inputfile
                +"\"),\"utf8\"))))"
            ], stdout=subprocess.PIPE)
    out=json.loads(p.stdout.read())
    return out

def scanforfunctions(compilationunit):
    funs={}
    for bla in compilationunit:
        if bla["declarator"]["type"]=="function":
            funname=bla["declarator"]["base"]["name"]
            funs[funname]=bla["body"]
    return funs

nodecounter = 0

def createNode():
    global nodecounter
    nodecounter =   1 + nodecounter
    return nodecounter

edgekeeper = []

def createEdge(fro,label,to):
    label =  { "from":fro,"label":label,"to":to }
    global edgekeeper
    edgekeeper.append(label)
    return label

def scan_block(block,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    lastinstr=supposedstart
    currentedge={}
    for stmt in block["code"]:
        nextinstr=createNode()
        currentedge=scan_stmt(stmt,lastinstr,nextinstr,breakpoint,continuepoint,retpoint)
        lastinstr=nextinstr
    currentedge["to"]=supposedend
    return currentedge

def scan_expressionstmt(exprstmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    label=exprstmt["expr"]
    return createEdge(supposedstart,label,supposedend)

def scan_whilestmt(whlstmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    stmt=whlstmt["stmt"]
    cond =whlstmt["cond"] 
    truebranch = createNode()
    createEdge(supposedstart,cond,truebranch)
    scan_stmt(stmt,truebranch,supposedstart,supposedend,supposedstart,retpoint)
    neg=cond.copy()
    neg["inverted"]=True
    return createEdge(supposedstart,neg,supposedend)


def scan_forstmt(forstmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    init = forstmt["e1"]["expr"]
    cond = forstmt["e2"]["expr"] 
    inc  = forstmt["e3"]

    loopstart=createNode()
    createEdge(supposedstart,init,loopstart)


    stmt=forstmt["stmt"]

    truebranch = createNode()
    createEdge(loopstart,cond,truebranch)
    incstart = createNode()
    scan_stmt(stmt,truebranch,incstart,supposedend,loopstart,retpoint)
    createEdge(incstart,inc,loopstart)

    neg=cond.copy()
    neg["inverted"]=True
    return createEdge(loopstart,neg,supposedend)

def scan_dostmt(dostmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    stmt=dostmt["stmt"]
    cond =dostmt["cond"] 

    condpoint = createNode()
    scan_stmt(stmt,supposedstart,condpoint,supposedend,condpoint,retpoint)
    createEdge(condpoint,cond,supposedstart)
    neg=cond.copy()
    neg["inverted"]=True
    return createEdge(condpoint,neg,supposedend)

def scan_ifstmt(ifstmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    stmt=ifstmt["stmt"]
    cond =ifstmt["cond"] 

    truebranch = createNode()
    falsebranch = createNode()
    end = createNode()

    createEdge(supposedstart,cond,truebranch)
    scan_stmt(stmt,truebranch,end,breakpoint,continuepoint,retpoint)

    neg=cond.copy()
    neg["inverted"]=True

    if ("else" in ifstmt):
        createEdge(supposedstart,neg,falsebranch)
        elsestmt=ifstmt["else"]
        scan_stmt(elsestmt,falsebranch,end,breakpoint,continuepoint,retpoint)
    else:
        createEdge(supposedstart,neg,end)

    return createEdge(end,"empty",supposedend)

def scan_return(stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    return createEdge(supposedstart,"return "+stmt["expr"],retpoint)

def scan_breakstmt(stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    return createEdge(supposedstart,"empty",breakpoint)

def scan_continuestmt(stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    return createEdge(supposedstart,"empty",continuepoint)

def scan_stmt(stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint):
    match stmt["type"]:
        case "block":     return scan_block         (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "expr":      return scan_expressionstmt(stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "do":        return scan_dostmt        (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "while":     return scan_whilestmt     (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "if":        return scan_ifstmt        (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "return":    return scan_return        (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "for":       return scan_forstmt       (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "break":     return scan_breakstmt     (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
        case "continue":  return scan_continuestmt  (stmt,supposedstart,supposedend,breakpoint,continuepoint,retpoint)
#        case "goto":
#        case "switch": 
        case _: return createEdge(supposedstart,"not implemented",supposedend)

def renderEdge(edgelabel):
    if (not type(edgelabel) is dict):
        ret= str(edgelabel)
    else:
        if (not "left" in edgelabel):
            print(edgelabel)
        left = edgelabel["left"]
        if (left):
            ret= str(renderEdge(left))+edgelabel["operator"]+str(renderEdge(edgelabel["right"]))
            if ("inverted" in edgelabel):
                ret="!("+ret+")"
    return ret

def iterateEdges(collector,joinbytarget=True):
    if (joinbytarget==False):
        values = set(map(lambda x:x["from"], edgekeeper))
        packed = [[x,[[y["label"],y["to"]] for y in edgekeeper if y["from"]==x]] for x in values]
    else:
        values = set(map(lambda x:x["to"], edgekeeper))
        packed = [[x,[[y["label"],y["from"]] for y in edgekeeper if y["to"]==x]] for x in values]
    for p in packed:
        collector(p[0],p[1])

def defaultCollector(src,edges):
    print("("+str(src)+","+str(edges)+")")

def graphvizCollector(out,src,edges):
    src=str(src)
    edgecounter=0
    for edge in edges:
        edgecounter+=1
        edgelab=src+"e"+str(edgecounter)
        to=str(edge[1])
        out.append("\n  s"+src+" [shape=circle,fillcolor=yellow,style=filled,label=\""+src+"\"] ")
        out.append("\n  s"+to+" [shape=circle,fillcolor=yellow,style=filled,label=\""+to+"\"] ")
        out.append("\n  e"+edgelab+" [shape=box, color=blue, label=\""+renderEdge(edge[0])+"\"]")
        out.append("\n s"+src+"-> e"+edgelab+" -> s"+to)

def intervalCollector(out,tgt,edges):
    target=str(tgt)
    rhs=[]
    for edge in edges:
        label=renderEdge(edge[0])
        rhs.append("⟦"+label+"⟧# I["+str(edge[1])+"]")
    rhs=" ⊔ ".join(rhs)
    out.append("I["+target+"] ⊒ "+rhs)

def polyCollector(out,src,edges):
    src=str(src)
    for edge in edges:
        label=renderEdge(edge[0])
        target=str(edge[1])
        out.append("I["+src+"] ⊒ ⟦"+label+"⟧♮ I["+target+"]")

CFG=0
INTERVALS=1
POLYNOMIALS=2

if __name__ == '__main__':
    if (len(sys.argv) <2):
        print("usage: almostANSI.py [inputfile.c] [option]")
        print("     -cfg         CFG in dot format, combines well with  | xdot /dev/stdin")
        print("     -intervals   interval analysis")
        print("     -polynomials polynomial relations analysis")
        quit()
    infile=sys.argv[1]
    out=parseANSIC(infile)
    funs = scanforfunctions(out)

    start=createNode()
    end=createNode()

    scan_stmt(funs["main"],start,end,end,start,end)

    #iterateEdges(defaultCollector)

    option=CFG
    if (len(sys.argv)==3):
        if (sys.argv[2]=="-intervals"):
            option=INTERVALS    
        if (sys.argv[2]=="-polynomials"):
            option=POLYNOMIALS 
        

    if option==CFG:
        out = ["digraph cfg { \n  rankdir=TB "]
        collector=functools.partial(graphvizCollector,out)
        iterateEdges(collector,joinbytarget=False)
        out.append("\n}")
        print("".join(out))
    
    if option==INTERVALS:
        out = []
        collector=functools.partial(intervalCollector,out)
        iterateEdges(collector)
        print("\n".join(out))

    if option==POLYNOMIALS:
        out = []
        collector=functools.partial(polyCollector,out)
        iterateEdges(collector,joinbytarget=False)
        print("\n".join(out))
    
#    printjson(funs["main"]["code"])

#        printjson(out)
#        printjson(out[1])
#        printjson(out[1]["loc"])
        