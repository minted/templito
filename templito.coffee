
events = require 'events'
fs = require 'fs'
path = require 'path'
utilities = require './utilities'
try
  _ = require 'underscore'
catch e
  console.warn 'Underscore could not be loaded. Precompiling templates will '+
               'not work until this problem is resolved.', e


###
# @class OutFile
###
class OutFile
  @existing = {}

  warning_message: """
  /* WARNING: This file was automatically generated by templito.
   * Do not manually edit this file if you plan to continue using templito.
   */\n\n
  """

  constructor: (_path, @options) ->
    @path = _path
    existing = OutFile.existing[@path]
    return existing if existing
    OutFile.existing[@path] = this

    @ee = new events.EventEmitter()
    # Set more listeners than we'll need
    @ee.setMaxListeners(5000);
    @defaulted_object_paths = []

    # Make all the needed directories for this file.
    utilities.mkdirp path.dirname(@path), =>
      @write @warning_message, =>
        @ee.emit 'ready'
        @ready = true
    return undefined # to supress annoying vim warning

  default_object_path: (object_paths...) ->
    defaults = []
    for object_path in object_paths
        parts = object_path.split '.'
        _parts = [parts[0]]
        # Don't initialize the namespace. If the namespace doesn't exist
        # before the templates are included, that's an error.
        for part in parts.slice 1
          _parts.push part
          part = _parts.join '.'
          if part not in @defaulted_object_paths
            _default = "#{part} || (#{part} = {});"
            defaults.push _default
            @defaulted_object_paths.push part
    defaults = defaults.join '\n'
    if defaults
      @append defaults + '\n\n'

  append_template: (name, fn, cb) ->
    object_path = name.split('.').slice(0, -1).join('.')
    @default_object_path object_path
    @append "#{name} = #{fn};\n\n", cb

  append: (text, cb) ->
    do_append = =>
      fs.appendFile @path, text, @file_options, (err) ->
        if err
          utilities.error "Error appending to #{@path}"
          throw err
        cb and cb()
    if @ready
      do_append()
    else
      @ee.once 'ready', do_append

  write: (text, cb) ->
    fs.writeFile @path, text, @file_options, (err) ->
      if err
        utilities.error "Error writing to #{@path}"
        throw err
      cb and cb()


###
# @class Template
###
class Template
  re_template_settings: /^\s*<!\-\-(\{[\s\S]+?\})\-\->/

  node_version = utilities.version_parts(process.version)
  file_options: if node_version[1] < 10 then 'utf8' else {encoding: 'utf8'}

  ###
  # @param path The path to the file from the base source directory.
  ###
  constructor: (_path, @options) ->
    @path = _path
    @basename = utilities.replace_extension(
      path.basename @path
      @options.extension
      ''
    )
    @name = utilities.to_case @options.function_case, @basename
    dirname = path.relative @options.source_dir, path.dirname(@path)
    dirname = path.join @options.source_dir_basename, dirname
    @path_parts = dirname.split path.sep
    @path_parts_cased = for part in @path_parts
      utilities.to_case @options.path_case, part
    @out_file = @get_out_file()

  get_out_file: ->
    # Get rid of the source_dir from @path_parts
    path_parts = @path_parts.slice 1

    # Get the path of the output file that should be used.
    compile_style = @options.compile_style
    loop
      # Find out the path to the file this template will be appended to
      fpath = switch compile_style
        when 'file' then path.join path_parts.concat(@basename)...
        when 'directory' then path.join path_parts...
        when 'combined' then @path_parts[0]

      # Paths directly in source_dir (no intermediate parent directories)
      # Should be compiled with the style 'file' instead to avoid confusion.
      if fpath is '.'
        compile_style = 'file'
        continue
      break

    ext = (if @options.keep_extension then @options.extension else '') + '.js'
    fpath = utilities.replace_extension fpath, @options.extension, ext

    new OutFile path.join(@options.out_dir, fpath), @options

  compile: (cb) ->
    fs.readFile @path, @file_options, (err, source) =>
      if err
        utilities.error "Error reading #{@path}"
        throw err

      # Get local file-level settings, if any
      file_settings = source.match(@re_template_settings)
      if file_settings
        file_settings = file_settings[1]
        file_settings = eval("(#{file_settings});")
        # Remove this from the source so we don't get compile errors.
        source = source.replace @re_template_settings, ''
      # Get the full template_settings object
      template_settings = _.extend({}, _.templateSettings,
          @options.template_settings, file_settings)
      # Compile the template function
      template_fn = _.template(source, null, template_settings)
      # Get full javascript path to compiled template
      template_path = [@options.namespace].concat(@path_parts_cased,
          [@name]).join('.')
      # Write to file
      @out_file.append_template template_path, template_fn.source, =>
        utilities.log "#{@path} -> #{@out_file.path}"
        cb and cb()

###
# Cleans the out_dir specified by the user. By clean, we mean totally remove.
# The user will be prompted before we remove the compiled directory unless
# they have turned the unsafe_clean option on.
#
# @param argv The arguments object from optimist
# @param cb A callback for when the clean operation is done
###
clean_out_dir = (argv, cb) ->
  utilities.with_prompter (prompter, close) ->
    clean = (yn) ->
      close()
      if yn in [true, 'y', 'Y']
        utilities.log "Removing #{argv.out_dir} prior to compiling..."
        utilities.rmdirr(argv.out_dir, false, cb)
    if argv.unsafe_clean
      clean true
    else
      prompter.question(
        "Really remove #{JSON.stringify argv.out_dir} and all its contents? (Y/n) ",
        clean
      )


###
# The main entry point from the cli _plate command. Does some basic sanity
# checking, performs the clean if requested and passes the rest on to _compile.
#
# @param argv the optimist argv object.
###
compiling = false
@compile = (argv, cb) ->
  return false if compiling
  compiling = true

  OutFile.existing = {}

  stats_cb = utilities.group_cb ([err1], [err2]) ->
    throw err if (err = err1 or err2)
    compile_dir argv.source_dir, argv, ->
      compiling = false
      cb and cb()

  cb1 = stats_cb()
  srcstat = fs.stat argv.source_dir, (err, stat) ->
    throw err if err
    if not stat.isDirectory()
      cb1(utilities.not_dir_error argv.source_dir)
    else
      cb1()

  out_cb = stats_cb()
  out_dirstat = fs.stat argv.out_dir, (err, stat) ->
    if err
      if err.code is 'ENOENT'
        return out_cb()
      else
        throw err

    if stat.isDirectory()
      if argv.clean
        clean_out_dir argv, out_cb
      else
        out_cb()
    else
      out_cb(utilities.not_dir_error argv.out_dir)

  true


###
# This function recursively gathers information about the files and directory
# structure so we can properly compile the template files. Ensures we only
# compile files with the proper extension.
#
# @param source_dir The source dir we are compiling from.
# @param options The original argv object from optimist
# @param cb A callback
###
compile_dir = (source_dir, options, cb) ->
  cb_group = utilities.group_cb cb

  fs.readdir source_dir, (err, contents) ->
    throw err if err
    for item in contents then do (item) ->
      itempath = path.join source_dir, item
      fs.stat itempath, (err, stat) ->
        throw err if err
        if stat.isDirectory()
          _cb = cb_group()
          compile_dir itempath, options, _cb
        else if path.extname(item) is options.extension
          _cb = cb_group()
          template = new Template itempath, options
          template.compile _cb

