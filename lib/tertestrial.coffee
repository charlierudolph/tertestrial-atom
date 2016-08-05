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
    buffer = editor.getBuffer()
    bufferSavedSubscription = buffer.onWillSave =>
      buffer.transact => @repeatLastTest(editor) if @autoTest

    editorDestroyedSubscription = editor.onDidDestroy =>
      bufferSavedSubscription.dispose()
      editorDestroyedSubscription.dispose()
      @subscriptions.remove(bufferSavedSubscription)
      @subscriptions.remove(editorDestroyedSubscription)

    @subscriptions.add(bufferSavedSubscription)
    @subscriptions.add(editorDestroyedSubscription)


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
    command = operation: 'repeatLastTest'
    message = if @autoTest then '' else 'repeating last test'
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
