{
    var isArray = Array.isArray;

    function makeArray(ctx) {
        return isArray(ctx)? ctx.slice() : [ctx];
    }

    function applyPathFns(ctx, fns) {
        var fn, i = 0, j, ctxLen, res = makeArray(ctx), fnRes;

        while(fn = fns[i++]) {
            j = 0;
            ctxLen = res.length;
            while(j < ctxLen) {
                fnRes = fn(res[j++]);
                if(Array.isArray(fnRes)) {
                    res = res.concat(fnRes);
                }
                else if(typeof fnRes !== 'undefined') {
                    res.push(fnRes);
                }
            }
            res.splice(0, ctxLen);
            if(!res.length) {
                break;
            }
        }

        return res;
    }

    function applyPredFns(ctx, fns) {
        var fn, i = 0, res = ctx;

        while((fn = fns[i++]) && typeof res !== 'undefined') {
            res = fn(res);
        }

        return res;
    }

    var binaryOps = {
        '===' : function(val1, val2) {
            return val1 === val2;
        },
        '==' : function(val1, val2) {
            return val1 == val2;
        },
        '>=' : function(val1, val2) {
            return val1 >= val2;
        },
        '>'  : function(val1, val2) {
            return val1 > val2;
        },
        '<=' : function(val1, val2) {
            return val1 <= val2;
        },
        '<'  : function(val1, val2) {
            return val1 < val2;
        }
    }

    function applyBinaryOp(val1, val2, op) {
        var opFn = binaryOps[op];
        return isArray(val1)?
            isArray(val2)?
                val1.some(function(val1) {
                    return val2.some(function(val2) {
                        return opFn(val1, val2);
                    });
                }) :
                val1.some(function(val1) {
                    return opFn(val1, val2);
                }) :
            isArray(val2)?
                val2.some(function(val2) {
                    return opFn(val1, val2);
                }) :
                opFn(val1, val2);
    }
}

start
    = path

path
    = '@' parts:([.]part)+ {
        return function(ctx) {
            return applyPathFns(
                ctx,
                parts.map(function(part) {
                    return part[1];
                }));
        }
    }
    / '@' {
        return function(ctx) {
            return makeArray(ctx);
        };
    }

part
    = prop:prop pred:pred* {
        return function(ctx) {
            return pred.length? applyPredFns(ctx[prop], pred) : ctx[prop];
        };
    }

prop
    = prop:[-_a-z0-9/]i+ {
        return prop.join('');
    }
    / '"' prop:[-_a-z0-9/.]i+ '"' {
        return prop.join('');
    }

pred
    = objPred
    / arrPred

objPred
    = '{' _ objPredRule:objPredRule _ '}' {
        return function(ctx) {
            return isArray(ctx)?
                ctx.filter(function(item) {
                    return objPredRule(item);
                }) :
                objPredRule(ctx)? ctx : undefined;
        }
    }

objPredRule
    = objPredRuleBinary
    / objPredHasProperty

objPredRuleBinary
    = left:exp _ binaryOp:binaryOp _ right:exp {
        return function(ctx) {
            return applyBinaryOp(left(ctx), right(ctx), binaryOp);
        }
    }

objPredHasProperty
    = path:path {
        return function(ctx) {
            return !!path(ctx).length;
        }
    }

binaryOp
    = '==='
    / '=='
    / '>='
    / '>'
    / '<='
    / '<'

exp
    = path
    / value:value {
        return function() {
            return value;
        }
    }

arrPred
    = '[' _ arrPredRule:arrPredRule _ ']' {
        return function(ctx) {
            return Array.isArray(ctx)?
                arrPredRule(ctx) :
                undefined;
        }
    }

arrPredRule
    = arrPredRuleBetween
    / arrPredRuleLess
    / arrPredRuleMore
    / arrPrevRuleIdx

arrPredRuleBetween
    = idxFrom:int '..' idxTo:int {
        return function(ctx) {
            return ctx.slice(idxFrom, idxTo);
        }
    }

arrPredRuleLess
    = '..' idx:int {
        return function(ctx) {
            return ctx.slice(0, idx);
        }
    }

arrPredRuleMore
    = idx:int '..' {
        return function(ctx) {
            return ctx.slice(idx);
        }
    }

arrPrevRuleIdx
    = idx:int {
        return function(ctx) {
            return idx >= 0? ctx[idx] : ctx[ctx.length + idx];
        }
    }

value
    = string
    / int

string "string"
    = '"' '"' _ { return ""; }
    / '"' chars:chars '"' _ { return chars; }

chars
    = chars:char+ { return chars.join(""); }

char
    = [^"\\\0-\x1F\x7f]
    / '\\"' { return '"'; }
    / "\\\\" { return "\\"; }
    / "\\/" { return "/"; }
    / "\\b" { return "\b"; }
    / "\\f" { return "\f"; }
    / "\\n" { return "\n"; }
    / "\\r" { return "\r"; }
    / "\\t" { return "\t"; }
    / "\\u" h1:hexDigit h2:hexDigit h3:hexDigit h4:hexDigit {
        return String.fromCharCode(parseInt("0x" + h1 + h2 + h3 + h4));
    }

hexDigit
    = [0-9a-fA-F]

int
    = sign:'-'? int:[0-9]+ { return parseInt(sign + int.join(''), 10); }

_ 'whitespace'
    = [ ]*