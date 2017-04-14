{CompositeDisposable} = require 'atom'
{coroutine, promisify} = require 'bluebird'
camelCase = require 'camel-case'
fs = require 'fs'
path = require 'path'
pathIsInside = require 'path-is-inside'


fsAccess = promisify fs.access
fsAppendFile = promisify fs.appendFile


module.exports =
  activate: ->
    @autoTest = false
    @lastDirectoryRunningTertestrial = null
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeTextEditors (editor) => @handleEvents(editor)
    @subscriptions.add atom.commands.add 'atom-workspace',
      'tertestrial:test-file': =>
        if editor = atom.workspace.getActiveTextEditor()
          @testFile(editor)
        else
          @notify "no file open", 'error'
      'tertestrial:test-line': =>
        if editor = atom.workspace.getActiveTextEditor()
          @testLine editor
        else
          @notify "no file open", 'error'
      'tertestrial:repeat-last-test': =>
        @repeatLastTest()
      'tertestrial:toggle-auto-test': =>
        @toggleAutoTest()
      'tertestrial:cycle-action-set': =>
        @cycleActionSet()


  cycleActionSet: ->
    command = cycleActionSet: 'next'
    message = 'cycling to the next action set'
    @sendCommand {command, message}


  deactivate: ->
    @subscriptions.dispose()


  findDirectoryRunningTertestrial: coroutine (filename) ->
    if yield @shouldUseLastDirectoryRunningTertestrial filename
      return @lastDirectoryRunningTertestrial
    rootDirectories = atom.project.rootDirectories.map (x) -> x.getPath()
    directory = if filename then path.dirname(filename) else rootDirectories[0]
    loop
      if yield @isTertestrialRunningInDirectory directory
        return directory
      else if directory in rootDirectories
        break
      else
        directory = path.dirname directory
    throw Error 'No directory found'


  handleEvents: (editor) ->
    editorSavedDisposable = editor.onDidSave =>
      @repeatLastTest(trigger: 'autoTest') if @autoTest

    editorDestroyedDisposable = editor.onDidDestroy =>
      editorSavedDisposable.dispose()
      editorDestroyedDisposable.dispose()
      @subscriptions.remove editorSavedDisposable
      @subscriptions.remove editorDestroyedDisposable

    @subscriptions.add editorSavedDisposable
    @subscriptions.add editorDestroyedDisposable


  isTertestrialRunningInDirectory: coroutine (directory) ->
    pipeFile = path.join directory, '.tertestrial.tmp'
    try
      yield fsAccess pipeFile
    catch err
      return false
    true


  notify: (message, type = 'info') ->
    fnName = camelCase "add_#{type}"
    atom.notifications[fnName] "Tertestrial: #{message}"


  repeatLastTest: ({trigger} = {}) ->
    command = repeatLastTest: true
    message = 'repeating last test'
    message += ' (auto test)' if trigger is 'autoTest'
    @sendCommand {command, message, trigger}


  sendCommand: coroutine ({command, filename, message, trigger}) ->
    try
      @lastDirectoryRunningTertestrial = yield @findDirectoryRunningTertestrial filename
    catch err
      @lastDirectoryRunningTertestrial = null
      message = 'could not find running tertestrial server'
      type = 'error'
      if trigger is 'autoTest'
        @autoTest = false
        message += ', auto test disabled'
        type = 'warning'
      @notify message, type
      return
    pipeFile = path.join @lastDirectoryRunningTertestrial, '.tertestrial.tmp'
    data = '\n' + JSON.stringify command
    try
      yield fsAppendFile pipeFile, data
    catch err
      @notify "error writing to pipe: #{err}", 'error'
      return
    @notify message


  shouldUseLastDirectoryRunningTertestrial: coroutine (filename) ->
    @lastDirectoryRunningTertestrial and
      (not filename or pathIsInside(filename, @lastDirectoryRunningTertestrial)) and
      yield @isTertestrialRunningInDirectory @lastDirectoryRunningTertestrial


  testFile: (editor) ->
    filename = editor.getPath()
    command = {filename}
    message = "testing current file"
    @sendCommand {command, filename, message}


  testLine: (editor) ->
    filename = editor.getPath()
    line = editor.getCursorBufferPosition().row + 1
    command = {filename, line}
    message = "testing current file at line #{line}"
    @sendCommand {command, filename, message}


  toggleAutoTest: ->
    @autoTest = !@autoTest
    @notify "auto test #{if @autoTest then 'enabled' else 'disabled'}"
