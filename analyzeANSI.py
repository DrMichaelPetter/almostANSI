#!/usr/bin/python3
import subprocess
import json
import sys

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

def scan_block(block,supposedstart,supposedend):
    lastinstr=supposedstart
    currentedge={}
    for stmt in block["code"]:
        nextinstr=createNode()
        currentedge=scan_stmt(stmt,lastinstr,nextinstr)
        lastinstr=nextinstr
    currentedge["to"]=supposedend
    return currentedge

def scan_expressionstmt(exprstmt,supposedstart,supposedend):
    label=exprstmt["expr"]
    return createEdge(supposedstart,label,supposedend)

def scan_whilestmt(whlstmt,supposedstart,supposedend):
    stmt=whlstmt["stmt"]
    cond =whlstmt["cond"] 
    truebranch = createNode()
    createEdge(supposedstart,cond,truebranch)
    scan_stmt(stmt,truebranch,supposedstart)
    neg=cond.copy()
    neg["inverted"]=True
    return createEdge(supposedstart,neg,supposedend)

def scan_ifstmt(ifstmt,supposedstart,supposedend):
    stmt=ifstmt["stmt"]
    elsestmt=ifstmt["else"]
    cond =ifstmt["cond"] 

    truebranch = createNode()
    falsebranch = createNode()
    end = createNode()

    createEdge(supposedstart,cond,truebranch)
    scan_stmt(stmt,truebranch,end)

    neg=cond.copy()
    neg["inverted"]=True
    createEdge(supposedstart,neg,falsebranch)
    scan_stmt(elsestmt,falsebranch,end)

    return createEdge(end,"empty",supposedend)

def scan_return(stmt,supposedstart,supposedend):
    return createEdge(supposedstart,"return "+stmt["expr"],supposedend)

def scan_stmt(stmt,supposedstart,supposedend):
    match stmt["type"]:
        case "block": return scan_block(stmt,supposedstart,supposedend)
        case "expr": return scan_expressionstmt(stmt,supposedstart,supposedend)
        case "while": return scan_whilestmt(stmt,supposedstart,supposedend)
        case "if": return scan_ifstmt(stmt,supposedstart,supposedend)
        case "return": return scan_return(stmt,supposedstart,supposedend)
#        case "do":
#        case "for":
#        case "break":
#        case "continue":
#        case "goto":    
        case _: return createEdge(supposedstart,"not implemented",supposedend)

def renderEdge(edgelabel):
    if (not type(edgelabel) is dict):
        ret= str(edgelabel)
    else:
        left = edgelabel["left"]
        if (left):
            ret= str(renderEdge(left))+edgelabel["operator"]+str(renderEdge(edgelabel["right"]))
            if ("inverted" in edgelabel):
                ret="!("+ret+")"
    return ret

def edges2dot():
    out= ("digraph cfg {")
    out+=("\n  rankdir=TB ")
    edgecounter=0
    for edge in edgekeeper:
        edgecounter+=1
        out+=("\n  s"+str(edge["to"])+" [shape=circle,fillcolor=yellow,style=filled,label=\""+str(edge["to"])+"\"] ")
        out+=("\n  s"+str(edge["from"])+" [shape=circle,fillcolor=yellow,style=filled,label=\""+str(edge["from"])+"\"] ")
        out+=("\n  e"+str(edgecounter)+" [shape=box, color=blue, label=\""+renderEdge(edge["label"])+"\"]")
        out+=("\n s"+str(edge["from"])+"-> e"+str(edgecounter)+" -> s"+str(edge["to"]))
    out+=("\n}")
    return out


if __name__ == '__main__':
    if (len(sys.argv) !=2):
        print("usage: almostANSI.py [inputfile.c] | xdot /dev/stdin")
        quit()
    infile=sys.argv[1]
    out=parseANSIC(infile)
    funs = scanforfunctions(out)

    scan_stmt(funs["main"],createNode(),createNode())

    print(edges2dot())

#    printjson(funs["main"]["code"])

#        printjson(out)
#        printjson(out[1])
#        printjson(out[1]["loc"])
        