esprima = require 'esprima'

canonicalise = require './canonicalise'

PRELUDE_NODE = """
var process = function(){
  var cwd = '/';
  return {
    title: 'browser',
    version: '#{process.version}',
    browser: true,
    env: {},
    argv: [],
    nextTick: global.setImmediate || function(fn){ setTimeout(fn, 0); },
    cwd: function(){ return cwd; },
    chdir: function(dir){ cwd = dir; }
  };
}();
"""

PRELUDE = '''
function require(file, parentModule){
  if({}.hasOwnProperty.call(require.cache, file))
    return require.cache[file];

  var resolved = require.resolve(file);
  if(!resolved) throw new Error('Failed to resolve module ' + file);

  var module$ = {
    id: file,
    require: require,
    filename: file,
    exports: {},
    loaded: false,
    parent: parentModule,
    children: []
  };
  if(parentModule) parentModule.children.push(module$);
  var dirname = file.slice(0, file.lastIndexOf('/') + 1);

  require.cache[file] = module$.exports;
  resolved.call(module$.exports, module$, module$.exports, dirname, file);
  module$.loaded = true;
  return require.cache[file] = module$.exports;
}

require.modules = {};
require.cache = {};

require.resolve = function(file){
  return {}.hasOwnProperty.call(require.modules, file) ? require.modules[file] : void 0;
};
require.define = function(file, fn){ require.modules[file] = fn; };
'''

wrapFile = (name, program) ->
  wrapperProgram = esprima.parse 'require.define(0, function(module, exports, __dirname, __filename){});'
  wrapper = wrapperProgram.body[0]
  wrapper.expression.arguments[0] = { type: 'Literal', value: name }
  wrapper.expression.arguments[1].body.body = program.body
  wrapper

ANONYMOUS_AMD_WRAPPER = '''
(function(exported) {
  if (typeof define === 'function' && define.amd)
    define([], function() { return exported; });
  if (typeof exports === 'object')
    module.exports = exported;
}(_));
'''

AMD_WRAPPER = '''
(function(exported) {
  if (typeof define === 'function' && define.amd)
    define(_, [], function() { return exported; });
  if (typeof exports === 'object')
    module.exports = exported;
  else
    _;
}(_));
'''

# XXX: we mutate the `program` parameter here for performance reasons
amdWrap = (maybeExport, requireEntryPoint) ->
  # include the program in the wrapper
  wrapper = esprima.parse (if maybeExport? then AMD_WRAPPER else ANONYMOUS_AMD_WRAPPER)
  wrapper.body[0].expression.arguments[0] = requireEntryPoint
  # require/expose the entry point if necessary
  if maybeExport?
    wrapper.body[0].expression.callee.body.body[1].alternate.expression =
      exportAs maybeExport, wrapper.body[0].expression.callee.params[0]
    wrapper.body[0].expression.callee.body.body[0].consequent.expression.arguments[0] =
      type: 'Literal'
      value: maybeExport
  wrapper

IIFE_WRAPPER = '(function(global){ /* ... */ }).call(this, this);'

# if an identifier is given as the export string, assume global member; otherwise just use it as LHS
exportAs = (exportString, requireEntryPoint) ->
  exportExpression = (esprima.parse exportString).body[0].expression
  type: 'AssignmentExpression'
  operator: '='
  right: requireEntryPoint
  left:
    if exportExpression.type is 'Identifier'
      type: 'MemberExpression'
      computed: false
      object: { type: 'Identifier', name: 'global' }
      property: { type: 'Identifier', name: exportExpression.name }
    else
      exportExpression

module.exports = (processed, entryPoint, root, options) ->
  prelude = if options.node ? yes then "#{PRELUDE}\n#{PRELUDE_NODE}" else PRELUDE
  program = esprima.parse prelude
  for own filename, {ast} of processed
    program.body.push wrapFile ast.loc.source, ast

  requireEntryPoint =
    type: 'CallExpression'
    callee: { type: 'Identifier', name: 'require' }
    arguments: [{ type: 'Literal', value: canonicalise root, entryPoint }]

  # require/expose the entry point
  if options.amd
    program.body.push amdWrap options.export, requireEntryPoint
  else
    program.body.push
      type: 'ExpressionStatement'
      expression:
        if options.export?
          exportAs options.export, requireEntryPoint
        else
          requireEntryPoint

  # wrap the program in an IIFE for scope safety; also, define `global` var here
  iife = esprima.parse IIFE_WRAPPER
  iife.body[0].expression.callee.object.body.body = program.body
  iife.leadingComments = [
    type: 'Line'
    value: " Generated by CommonJS Justhere #{(require '../package.json').version}"
  ]

  iife
