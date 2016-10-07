{CompositeDisposable} = require 'atom'
camelCase = require 'camel-case'
fs = require 'fs'
path = require 'path'


module.exports =
  activate: ->
    @autoTest = false
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


  notify: (message, type = 'info') ->
    fnName = camelCase "add_#{type}"
    atom.notifications[fnName] "Tertestrial: #{message}"


  repeatLastTest: ({trigger} = {}) ->
    command = repeatLastTest: true
    message = 'repeating last test'
    message += ' (auto test)' if trigger is 'autoTest'
    @sendCommand {command, message, trigger}


  sendCommand: ({command, message, trigger}) ->
    if atom.project.rootDirectories.length isnt 1
      @notify 'requires a single root directory', 'error'
    else
      projectPath = atom.project.rootDirectories[0].getPath()
      pipeFile = path.join projectPath, '.tertestrial.tmp'
      fs.access pipeFile, (err) =>
        if err
          if trigger is 'autoTest'
            @autoTest = false
            @notify "server is not running, auto test disabled", 'warning'
          else
            @notify "server is not running", 'error'
        else
          data = '\n' + JSON.stringify command
          fs.appendFile pipeFile, data, (err) =>
            if err
              @notify "error writing to pipe: #{err}", 'error'
            else
              @notify message


  testFile: (editor) ->
    filename = editor.getPath()
    command = {filename}
    message = "testing current file"
    @sendCommand {command, message}


  testLine: (editor) ->
    filename = editor.getPath()
    line = editor.getCursorBufferPosition().row + 1
    command = {filename, line}
    message = "testing current file at line #{line}"
    @sendCommand {command, message}


  toggleAutoTest: ->
    @autoTest = !@autoTest
    @notify "auto test #{if @autoTest then 'enabled' else 'disabled'}"
