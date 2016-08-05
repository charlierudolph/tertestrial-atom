{CompositeDisposable} = require 'atom'

module.exports =
  activate: ->
    @autoTest = false
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.observeTextEditors (editor) => @handleEvents(editor)
    @subscriptions.add atom.commands.add 'atom-workspace',
      'tertestrial:test-file': =>
        @testFile(editor) if editor = atom.workspace.getActiveTextEditor()
      'tertestrial:test-line': =>
        @testLine(editor) if editor = atom.workspace.getActiveTextEditor()
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


  testFile: (editor) ->
    filename = editor.getPath()
    command = {filename}
    message = "testing file #{filename}"
    @sendCommand command, message


  testLine: (editor) ->
    filename = editor.getPath()
    line = editor.getCursorBufferPosition().row
    command = {filename, line}
    message = "testing file #{filename} at line #{line}"
    @sendCommand command, message


  repeatLastTest: ->
    command = operation: 'repeatLastTest'
    message = if @autoTest then '' else 'repeating last test'
    @sendCommand command, message


  sendCommand: (command, message) ->
    if @rootDirectories.length !== 1
      atom.notifications.addError "tertestrial requires a single root directory"
    else
      projectPath = @rootDirectories[0].getPath()
      pipeFile = path.join projectPath, '.tertestrial.tmp'
      fs.access pipeFile, (err) ->
        if err
          atom.notifications.addError "tertestrial server is not running"
        else
          fs.appendFile pipeFile, JSON.stringify(command), (err) ->
            if err
              atom.notifications.addError "error writing to tertestrial pipe"
            else
              atom.notifications.addInfo message


  toggleAutoTest: ->
    @autoTest = !@autoTest
    atom.notifications.addInfo "autoRepeat is #{if @autoTest then 'on' else 'off'}"
