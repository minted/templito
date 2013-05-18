path = require 'path'
optimist = require 'optimist'
templito = require './'

argv = require('optimist')
.usage('Compiles underscore.js templates into javascript files.\n\n' +
       'templito source-dir out-dir [options]')
.options(
  c:
    alias: 'compile-style'
    describe: 'Options include: "combined" (single file), "directory" (one ' +
              'file per directory) and "file" (one output file per input ' +
              'file).'
    default: 'directory'
  p:
    alias: 'path-case'
    describe: 'The casing for the object path part of an output ' +
              'function\'s address. If the template is ' +
              'source_dir/a/b/c.html, then the object path part is ' +
              'source_dir/a/b. Options include "camelCase", "CapitalCase", ' +
              ' and "snake_case".'
    default: 'CapitalCase'
  f:
    alias: 'function-case'
    describe: 'The casing for the output function\'s name. Options are the ' +
              'same as for the path-case option.'
    default: 'camelCase'
  e:
    alias: 'extension'
    describe: 'templito will look for files with the given extension.'
    default: '.html'
  k:
    alias: 'keep-extension'
    describe: 'Whether or not the output files should keep the original ' +
              'file extension as part of its name.'
    default: false
  n:
    alias: 'namespace'
    describe: 'The namespace to add your compiled template functions to.'
    default: 'App'
  s:
    alias: 'template-settings'
    describe: 'A javascript object that will override _.templateSettings.'
  h:
    alias: 'help'
    describe: 'Show this help message and exit.'
  C:
    alias: 'clean'
    describe: 'Empty the out-dir before compiling.'
  U:
    alias: 'unsafe-clean'
    describe: 'Opt out of prompt before cleaning out-dir'
).argv

show_help = (msg) ->
  optimist.showHelp()
  console.error msg if msg
  process.exit msg ? 1 : 0

if argv.help
  show_help()

# Underscorify hyphenated keys
re_hyphen = /(\w*)\-(\w*)/g
for key, value of argv
  if re_hyphen.test key
    _key = key.replace re_hyphen, '$1_$2'
    argv[_key] = value

if argv.template_settings?
  try
    argv.template_settings = eval(argv.template_settings)
  catch e
    console.error "The template-settings you passed in " +
                  "(#{argv.template_settings}) does not appear to be a " +
                  "valid javascript object: #{e}"
    process.exit -1

argv.source_dir = argv._[0]
argv.out_dir = argv._[1]
if not (argv.source_dir and argv.out_dir)
  show_help 'Missing required argument'

argv.source_dir_basename = path.basename argv.source_dir

templito.compile argv

