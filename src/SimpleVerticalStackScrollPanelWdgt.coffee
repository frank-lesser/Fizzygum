# this comment below is needed to figure out dependencies between classes
# REQUIRES globalFunctions

class SimpleVerticalStackScrollPanelWdgt extends ScrollPanelWdgt

  constructor: (@isTextLineWrapping = true) ->
    VS = new SimpleVerticalStackPanelWdgt()

    if !@isTextLineWrapping
      VS.constrainContentWidth = false

    VS.tight = false
    VS.isLockingToPanels = true
    super VS
    @disableDrops()

    ostmA = new SimplePlainTextWdgt(
      "A small string\n\n\nhere another.",nil,nil,nil,nil,nil,WorldMorph.preferencesAndSettings.editableItemBackgroundColor, 1)
    ostmA.isEditable = true
    ostmA.enableSelecting()
    @setContents ostmA, 5
    @setColor new Color 249, 249, 249

  colloquialName: ->
    "stack"

  addMorphSpecificMenuEntries: (morphOpeningThePopUp, menu) ->
    super
    menu.removeMenuItem "move all inside"

    childrenNotHandlesNorCarets = @contents?.children.filter (m) ->
      !((m instanceof HandleMorph) or (m instanceof CaretMorph))

    if childrenNotHandlesNorCarets? and childrenNotHandlesNorCarets.length > 0
      menu.addLine()
      if !@dragsDropsAndEditingEnabled
        menu.addMenuItem "enable editing", true, @, "enableDragsDropsAndEditing", "lets you drag content in and out"
      else
        menu.addMenuItem "disable editing", true, @, "disableDragsDropsAndEditing", "prevents dragging content in and out"

    menu.removeConsecutiveLines()

  enableDragsDropsAndEditing: (triggeringWidget) ->
    if !triggeringWidget? then triggeringWidget = @
    if @dragsDropsAndEditingEnabled
      return
    @parent?.makePencilYellow?()
    if @parent? and @parent != triggeringWidget and @parent instanceof SimpleDocumentWdgt
      @parent.enableDragsDropsAndEditing @
    else
      super @

  disableDragsDropsAndEditing: (triggeringWidget) ->
    if !triggeringWidget? then triggeringWidget = @
    if !@dragsDropsAndEditingEnabled
      return
    @parent?.makePencilClear?()
    if @parent? and @parent != triggeringWidget and @parent instanceof SimpleDocumentWdgt
      @parent.disableDragsDropsAndEditing @
    else
      super @