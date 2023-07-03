# pip install pyinterval --break-system-packages
from interval import interval,inf #,imath

def interval_lub(left,right):
    return interval([left,right])
def interval_intersect(left,right):
    return left & right
def interval_top():
    return interval[-inf,inf]
def interval_bot():
    return interval()

def state_init(vars):
    mymap = {}
    for var in vars:
        mymap[var]=interval_bot()
    return mymap

def state_join(state1,state2):
    if (len(state2)==0):
        return state1
    join = state2.copy()
    for k,v in state1.items():
        v2 = state2.get(k,interval_bot())
        join[k]=interval_lub(v,v2)
    return join

def state_leq(state1,state2):
    for k,v in state1.items():
        vcomp = state2.get(k,interval_bot())
        if (not v in vcomp):
            return False
    return True

def state_expr(state,expr):
    if type(expr)==str:
        if expr in state:
            return state,state[expr]
        else:
            if (expr.isnumeric()):
                return state,interval(int(expr))
            else:
                return state,interval_top()
    match(expr["operator"]):
        case "<": 
            if type(expr["left"])==str:
                mystate,val = state_expr(state,expr["right"])
                mystate=mystate.copy()
                if "inverted" in expr:
                    mystate[expr["left"]]=interval_intersect(mystate.get(expr["left"],interval_top()),interval[val+1,inf])
                else:    
                    mystate[expr["left"]]=interval_intersect(mystate.get(expr["left"],interval_top()),interval[-inf,val])
                return mystate,val
            else:
                return state,interval_top()
        case "=":
            if type(expr["left"])==str:
                mystate,val = state_expr(state,expr["right"])
                mystate=mystate.copy()
                mystate[expr["left"]]=val
                return mystate,val 
            else:
                return state,interval_top()
        case "+":  
            _,lval=state_expr(state,expr["left"])
            _,rval=state_expr(state,expr["right"])
            return state,lval+rval
        case "-": 
            _,lval=state_expr(state,expr["left"])
            _,rval=state_expr(state,expr["right"])
            return state,lval-rval
        case "/": 
            _,lval=state_expr(state,expr["left"])
            _,rval=state_expr(state,expr["right"])
            return state,lval/rval
        case "*": 
            _,lval=state_expr(state,expr["left"])
            _,rval=state_expr(state,expr["right"])
            return state,lval*rval
        case _  : return state,interval_top()


def round_robin(constraints,values):
    changed=True
    itercounter=0
    #print(values)
    while(changed and itercounter < 50):
        itercounter+=1
        #print(itercounter)
        changed=False
        for statenum,exprs in constraints.items():
            oldval=values.get(statenum,state_init([]))
            acc={}
            for expr,src in exprs:
                srcval=values.get(src,state_init([]))
                if (len(srcval)!=0):
                    newval,exprval=state_expr(srcval,expr)
                    acc=state_join(newval,acc)
                    #print(src," -> ",str(statenum),": ",srcval," -> ",acc)
            if not state_leq(acc,oldval):
                changed=True
                values[statenum]=acc
        
