{$, TextEditorView, View}  = require 'atom-space-pen-views'


class UpdateActionSetView extends View


  @content: ->
    @div class: 'tertestrial-update-action-set', =>
      @subview 'miniEditor', new TextEditorView(mini: true)
      @div class: 'message', outlet: 'message'


  close: ->
    return unless @panel.isVisible()
    miniEditorFocused = @miniEditor.hasFocus()
    @miniEditor.setText('')
    @panel.hide()
    @restoreFocus() if miniEditorFocused


  confirm: ->
    actionSet = @miniEditor.getText()
    @close()
    @onUpdateActionSet actionSet


  initialize: (@onUpdateActionSet) ->
    @panel = atom.workspace.addModalPanel item: @, visible: false
    @miniEditor.on 'blur', => @close()
    atom.commands.add @miniEditor.element, 'core:confirm', => @confirm()
    atom.commands.add @miniEditor.element, 'core:cancel', => @close()


  open: ->
    return if @panel.isVisible()
    @storeFocusedElement()
    @panel.show()
    @message.text 'Enter the Tertestrial action set to use'
    @miniEditor.focus()


  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      atom.views.getView(atom.workspace).focus()


  storeFocusedElement: ->
    @previouslyFocusedElement = $(':focus')


  toggle: ->
    if @panel.isVisible()
      @close()
    else
      @open()


module.exports = UpdateActionSetView
