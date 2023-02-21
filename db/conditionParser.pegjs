{
  // Declared by PEG: input, options, parser, text(), location(), expected(), error()

  var context = options.context
  var attrNames = context.attrNames || {}
  var attrVals = context.attrVals || {}
  var unusedAttrNames = context.unusedAttrNames || {}
  var unusedAttrVals = context.unusedAttrVals || {}
  var isReserved = context.isReserved
  var errors = Object.create(null)
  var nestedPaths = Object.create(null)
  var pathHeads = Object.create(null)
    
  function checkReserved(name) {
    if (isReserved(name) && !errors.reserved) {
      errors.reserved = 'Attribute name is a reserved keyword; reserved keyword: ' + name
    }
  }

  function resolveAttrName(name) {
    if (errors.attrNameVal) {
      return
    }
    if (!attrNames[name]) {
      errors.attrNameVal = 'An expression attribute name used in the document path is not defined; attribute name: ' + name
      return
    }
    delete unusedAttrNames[name]
    return attrNames[name]
  }

  function resolveAttrVal(name) {
    if (errors.attrNameVal) {
      return
    }
    if (!attrVals[name]) {
      errors.attrNameVal = 'An expression attribute value used in expression is not defined; attribute value: ' + name
      return
    }
    delete unusedAttrVals[name]
    return attrVals[name]
  }

  function checkFunction(name, args) {
    if (errors.unknownFunction) {
      return
    }
    var functions = {
      attribute_exists: 1,
      attribute_not_exists: 1,
      attribute_type: 2,
      begins_with: 2,
      contains: 2,
      size: 1,
    }
    var numOperands = functions[name]
    if (numOperands == null) {
      errors.unknownFunction = 'Invalid function name; function: ' + name
      return
    }

    if (errors.operand) {
      return
    }
    if (numOperands != args.length) {
      errors.operand = 'Incorrect number of operands for operator or function; ' +
        'operator or function: ' + name + ', number of operands: ' + args.length
      return
    }

    checkDistinct(name, args)

    if (errors.function) {
      return
    }
    switch (name) {
      case 'attribute_exists':
      case 'attribute_not_exists':
        if (!Array.isArray(args[0])) {
          errors.function = 'Operator or function requires a document path; ' +
            'operator or function: ' + name
          return
        }
        return getType(args[1])
      case 'begins_with':
        for (var i = 0; i < args.length; i++) {
          var type = getType(args[i])
          if (type && type != 'S' && type != 'B') {
            errors.function = 'Incorrect operand type for operator or function; ' +
              'operator or function: ' + name + ', operand type: ' + type
            return
          }
        }
        return 'BOOL'
      case 'attribute_type':
        var type = getType(args[1])
        if (type != 'S') {
          if (type == null) type = '{NS,SS,L,BS,N,M,B,BOOL,NULL,S}'
          errors.function = 'Incorrect operand type for operator or function; ' +
            'operator or function: ' + name + ', operand type: ' + type
          return
        }
        if (!~['S', 'N', 'B', 'NULL', 'SS', 'BOOL', 'L', 'BS', 'NS', 'M'].indexOf(args[1].S)) {
          errors.function = 'Invalid attribute type name found; type: ' +
            args[1].S + ', valid types: {B,NULL,SS,BOOL,L,BS,N,NS,S,M}'
          return
        }
        return 'BOOL'
      case 'size':
        var type = getType(args[0])
        if (~['N', 'BOOL', 'NULL'].indexOf(type)) {
          errors.function = 'Incorrect operand type for operator or function; ' +
            'operator or function: ' + name + ', operand type: ' + type
          return
        }
        return 'N'
      case 'contains':
        return 'BOOL'
    }
  }

  function redundantParensError() {
    if (!errors.parens) {
      errors.parens = 'The expression has redundant parentheses;'
    }
  }

  function checkMisusedFunction(args) {
    if (errors.misusedFunction) {
      return
    }
    for (var i = 0; i < args.length; i++) {
      if (args[i] && args[i].type == 'function' && args[i].name != 'size') {
        errors.misusedFunction = 'The function is not allowed to be used this way in an expression; function: ' +
          args[i].name
        return
      }
    }
  }

  function checkMisusedSize(expr) {
    if (expr.type == 'function' && expr.name == 'size' && !errors.misusedFunction) {
      errors.misusedFunction = 'The function is not allowed to be used this way in an expression; function: ' + expr.name
    }
  }

  function checkDistinct(name, args) {
    if (errors.distinct || args.length != 2 || !Array.isArray(args[0]) || !Array.isArray(args[1]) || args[0].length != args[1].length) {
      return
    }
    for (var i = 0; i < args[0].length; i++) {
      if (args[0][i] !== args[1][i]) {
        return
      }
    }
    errors.distinct = 'The first operand must be distinct from the remaining operands for this operator or function; operator: ' +
      name + ', first operand: ' + pathStr(args[0])
  }

  function checkBetweenArgs(x, y) {
    if (errors.function) {
      return
    }
    var type1 = getImmediateType(x)
    var type2 = getImmediateType(y)
    if (type1 && type2) {
      if (type1 != type2) {
        errors.function = 'The BETWEEN operator requires same data type for lower and upper bounds; ' +
          'lower bound operand: AttributeValue: {' + type1 + ':' + x[type1] + '}, ' +
          'upper bound operand: AttributeValue: {' + type2 + ':' + y[type2] + '}'
      } else if (context.compare('GT', x, y)) {
        errors.function = 'The BETWEEN operator requires upper bound to be greater than or equal to lower bound; ' +
          'lower bound operand: AttributeValue: {' + type1 + ':' + x[type1] + '}, ' +
          'upper bound operand: AttributeValue: {' + type2 + ':' + y[type2] + '}'
      }
    }
  }

  function pathStr(path) {
    return '[' + path.map(function(piece) {
      return typeof piece == 'number' ? '[' + piece + ']' : piece
    }).join(', ') + ']'
  }

  function getType(val) {
    if (!val || typeof val != 'object' || Array.isArray(val)) return null
    if (val.attrType) return val.attrType
    return getImmediateType(val)
  }

  function getImmediateType(val) {
    if (!val || typeof val != 'object' || Array.isArray(val) || val.attrType) return null
    var types = ['S', 'N', 'B', 'NULL', 'BOOL', 'SS', 'NS', 'BS', 'L', 'M']
    for (var i = 0; i < types.length; i++) {
      if (val[types[i]] != null) return types[i]
    }
    return null
  }

  function checkConditionErrors() {
    if (errors.condition) {
      return
    }
    var errorOrder = ['attrNameVal', 'operand', 'distinct', 'function']
    for (var i = 0; i < errorOrder.length; i++) {
      if (errors[errorOrder[i]]) {
        errors.condition = errors[errorOrder[i]]
        return
      }
    }
  }

  function checkErrors() {
    var errorOrder = ['parens', 'unknownFunction', 'misusedFunction', 'reserved', 'condition']
    for (var i = 0; i < errorOrder.length; i++) {
      if (errors[errorOrder[i]]) return errors[errorOrder[i]]
    }
    return null
  }
    
	// Precedence
	let symbols = {
        'AND': {
        	prec: 0
        },
        'OR': {
        	prec: 1
        },
        'IN' : {
        	prec: 1
        },
        'BETWEEN': {
        	prec: 1
        },
        '<': {
        	prec: 2
        },
        '>': {
        	prec: 2
        },
        '=': {
        	prec: 2
		    },
        '<>': {
        	prec: 2
        },
        '<=': {
        	prec: 2
        },
        '>=': {
        	prec: 2
        }
    };

    function Identifier(a) {
    	return a.toUpperCase()
    }
    
    function Call(a, b) {
      // Validate Args
      let args = b
      
      if (a.toUpperCase() === 'BETWEEN')
      	checkBetweenArgs(args[0], args[1])
        
       // Hack
       if (Array.isArray(b[1][0]) && Array.isArray(b[1][1])) {
       	args = [b[0], ...b[1]]
       }
        
     return {
        type: a.toLowerCase(),
        args
      }
    }

	function ResolveAttributes(a) {
    if (attrNames[a]) {
      delete unusedAttrNames[a]
      return attrNames[a]
    }

    if (attrVals[a]) {
      delete unusedAttrVals[a]
      return attrVals[a]
    }

    return a
    }
    
    function ShuntingYard(a, b) {
     	if (b.length === 0) {
   		return a
    }
  
    const stack = [[a, b[0][0]]];
    let top = b[0][1];
    for (let i=1, ilen = b.length; i<ilen; ++i) {
    	const [o1, n] = b[i];
        
        for (let j=stack.length - 1; j>=0; --j) {
         const [v1, o2] = stack[j];
         
         const pd = symbols[o2.toUpperCase()].prec - symbols[o1.toUpperCase()].prec;
         if (pd > 0 || pd === 0) {
         	stack.pop()
            top = Call(Identifier(o2), [v1, top]);
         } else {
         	break;
           }
        }
        
        stack.push([top, o1]);
        top = n;
    }
    
    for (let j=stack.length -1; j>= 0; --j) {
    	const [v1, o2] = stack[j];
        top = Call(Identifier(o2), [v1, top]);
    }
    return top;
    }
}

Start = expr:NotExpression {
      return checkErrors() || {expression: expr, nestedPaths: nestedPaths, pathHeads: pathHeads}
}

NotExpression
 = 'NOT'i _ a:Expression {
	return {
    	type: 'not',
        args: [a]
    }
} / Expression

Expression
  = _ a:Token b:(@Symbol _ @Token _)* {
  	return ShuntingYard(a,b)
  }

Token
  = Function
  / Group
  / Braced

Identity
  = a:$[A-Za-z_0-9:#]+ _ {
  	const resolved = ResolveAttributes(a)
    // This might be wrong
  	pathHeads[resolved] = true
  	return resolved
  }

Group
 = '(' a:Path b:(',' _ @Path)+ ')' _ {
 	return [a,...b]
 }
 / a:Path {
 	return a
 }

Function
  = name:FunctionNames "(" _ args:Args ")" _ {

    const attrType = checkFunction(name, args)

    return {
    	type: 'function',
        name,
        args,
        attrType
    }
   }
  
FunctionNames
  = @( 'attribute_exists'i
  / 'attribute_not_exists'i
  / 'attribute_type'i
  / 'begins_with'i
  / 'contains'i
  / 'size'i ) _

Args
 = a:Path b:(','_ @Path )+ {
 	return [a, ...b]
 }
 / a:Path {
 	return [a]
 }

Path
 = a:(@Identity) _ b:('.' @Identity _)+ {
 	nestedPaths[a] = true
 	return [a, ...b]
 }
 / a:Identity {
 	return [a]
 }

Braced
  = "(" _ "(" _ expr:NotExpression ")" _ ")" _ {
    redundantParensError()
    return expr
  }
  / "(" _ @NotExpression ")" _

Symbol
  = 'AND'i /  'OR'i  / 'IN'i / 'BETWEEN'i  / '=' / '<>' / '>' / '<' / '>=' / '<='

 _ 'whitespace'
 	= [ /n/t/r]*