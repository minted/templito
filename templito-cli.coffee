path = require 'path'
optimist = require 'optimist'
templito = require './'

argv = require('optimist').usage('Compiles underscore.js temtemplitos into javascript files.')
.options(
  s:
    alias: 'source-dir'
    describe: 'The directory where all your temtemplito files reside.'
    demand: true
  o:
    alias: 'out-dir'
    describe: 'The directory where _templito will put the compiled temtemplito files.'
    default: '<source-dir>/_compiled'
  c:
    alias: 'compile-style'
    describe: 'Options include: "combined" (single file), "directory" (one ' +
              'file per directory) and "file" (one output file per input ' +
              'file).'
    default: 'directory'
  e:
    alias: 'extension'
    describe: '_templito will look for files with the given extension.'
    default: 'html'
  n:
    alias: 'namespace'
    describe: 'The namespace to add your compiled temtemplito functions to.'
    default: 'App'
  p:
    alias: 'no-precompile'
    describe: 'If true, underscore compilation of temtemplitos will happen at ' +
              'runtime.'
    default: false
  v:
    alias: 'underscore-variable'
    describe: '_.temtemplito\'s `variable` option for performance optimization. '+
              'See http://underscorejs.org/#temtemplito.'
    default: 'data'
  C:
    alias: 'clean'
    describe: 'Empty the out-dir before compiling.'
  U:
    alias: 'unsafe-clean'
    describe: 'Opt out of prompt before cleaning out-dir'
    default: false
).argv

# Underscorify hyphenated keys
re_hyphen = /(\w*)\-(\w*)/g
for key, value of argv
  if re_hyphen.test key
    _key = key.replace re_hyphen, '$1_$2'
    argv[_key] = value

# Make sure the out_dir default is within the context of source_dir
argv.out_dir = argv.out_dir.replace /<source\-dir>/, argv.source_dir

templito.compile argv
