{CompositeDisposable} = require 'atom'
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
          @notify "no file open", error: true
      'tertestrial:test-line': =>
        if editor = atom.workspace.getActiveTextEditor()
          @testLine editor
        else
          @notify "no file open", error: true
      'tertestrial:repeat-last-test': =>
        @repeatLastTest()
      'tertestrial:toggle-auto-test': =>
        @toggleAutoTest()


  deactivate: ->
    @subscriptions.dispose()


  handleEvents: (editor) ->
    editorSavedDisposable = editor.onDidSave =>
      @repeatLastTest() if @autoTest

    editorDestroyedDisposable = editor.onDidDestroy =>
      editorSavedDisposable.dispose()
      editorDestroyedDisposable.dispose()
      @subscriptions.remove editorSavedDisposable
      @subscriptions.remove editorDestroyedDisposable

    @subscriptions.add editorSavedDisposable
    @subscriptions.add editorDestroyedDisposable


  notify: (message, {error} = {}) ->
    prefixedMessage = "Tertestrial: #{message}"
    if error
      atom.notifications.addError prefixedMessage
    else
      atom.notifications.addInfo prefixedMessage


  testFile: (editor) ->
    filename = editor.getPath()
    command = {filename}
    message = "testing file #{filename}"
    @sendCommand {command, message}


  testLine: (editor) ->
    filename = editor.getPath()
    line = editor.getCursorBufferPosition().row + 1
    command = {filename, line}
    message = "testing file #{filename} at line #{line}"
    @sendCommand {command, message}


  repeatLastTest: ->
    command = repeatLastTest: true
    message = 'repeating last test'
    @sendCommand {command, message}


  sendCommand: ({command, message}) ->
    if atom.project.rootDirectories.length isnt 1
      atom.notifications.addError "Tertestrial: requires a single root directory"
    else
      projectPath = atom.project.rootDirectories[0].getPath()
      pipeFile = path.join projectPath, '.tertestrial.tmp'
      fs.access pipeFile, (err) =>
        if err
          @notify "server is not running", error: true
        else
          fs.appendFile pipeFile, JSON.stringify(command), (err) =>
            if err
              @notify "error writing to pipe: #{err}", error: true
            else
              @notify message


  toggleAutoTest: ->
    @autoTest = !@autoTest
    @notify "auto test is #{if @autoTest then 'on' else 'off'}"
