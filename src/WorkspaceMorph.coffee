# WorkspaceMorph //////////////////////////////////////////////////////

# just an experiment to see how a "close" button at the top left of
# any window would look like. Unclear why I called it something
# so important given that this looks like a temporary experiment.

class WorkspaceMorph extends BoxMorph
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype

  # panes:
  morphsList: null
  buttonClose: null
  resizer: null

  constructor: (target) ->
    super()

    @silentSetExtent new Point(
      WorldMorph.preferencesAndSettings.handleSize * 10,
      WorldMorph.preferencesAndSettings.handleSize * 20 * 2 / 3)
    @isfloatDraggable = true
    @cornerRadius = 5
    @color = new Color(60, 60, 60)
    @buildAndConnectChildren()
  
  setTarget: (target) ->
    @target = target
    @currentProperty = null
    @buildAndConnectChildren()
  
  buildAndConnectChildren: ->
    attribs = []

    # remove existing panes
    @fullDestroyChildren()

    # label
    @label = new TextMorph("Morphs List")
    @label.fontSize = WorldMorph.preferencesAndSettings.menuFontSize
    @label.isBold = true
    @label.color = new Color(255, 255, 255)
    @add @label

    # Check which objects end with the word Morph
    theWordMorph = "Morph"
    ListOfMorphs = (Object.keys(window)).filter (i) ->
      i.indexOf(theWordMorph, i.length - theWordMorph.length) isnt -1
    @morphsList = new ListMorph(ListOfMorphs, null)

    # so far nothing happens when items are selected
    #@morphsList.action = (selected) ->
    #  val = myself.target[selected]
    #  myself.currentProperty = val
    #  if val is null
    #    txt = "NULL"
    #  else if isString(val)
    #    txt = val
    #  else
    #    txt = val.toString()
    #  cnts = new TextMorph(txt)
    #  cnts.isEditable = true
    #  cnts.enableSelecting()
    #  cnts.setReceiver myself.target
    #  myself.detail.setContents cnts

    @morphsList.hBar.alpha = 0.6
    @morphsList.vBar.alpha = 0.6
    @add @morphsList

    # close button
    @buttonClose = new TriggerMorph(true, @)
    @buttonClose.setLabel "close"
    @buttonClose.action = "destroy"

    @add @buttonClose

    # resizer
    @resizer = new HandleMorph(@, @cornerRadius, @cornerRadius)

    # update layout
    @layoutSubmorphs()
  
  layoutSubmorphs: ->
    super()
    trackChanges.push false

    handleSize = WorldMorph.preferencesAndSettings.handleSize;

    x = @left() + @cornerRadius
    y = @top() + @cornerRadius
    r = @right() - @cornerRadius
    w = r - x

    # label
    @label.fullMoveTo new Point(x + handleSize * 2/3 + @cornerRadius, y - @cornerRadius/2)
    @label.setWidth w
    if @label.height() > (@height() - 50)
      @setHeight @label.height() + 50
      @changed()

    # morphsList
    y = @label.bottom() + @cornerRadius/2
    w = @width() - @cornerRadius
    w -= @cornerRadius
    b = @bottom() - (2 * @cornerRadius) - handleSize
    h = b - y
    @morphsList.fullMoveTo new Point(x, y)
    @morphsList.setExtent new Point(w, h)

    # close button
    x = @morphsList.left()
    y = @morphsList.bottom() + @cornerRadius
    h = handleSize
    w = @morphsList.width() - h - @cornerRadius
    @buttonClose.fullMoveTo new Point(x, y)
    @buttonClose.setExtent new Point(w, h)
    trackChanges.pop()
    @changed()
  
  setExtent: (aPoint) ->
    #console.log "move 19"
    @breakNumberOfMovesAndResizesCaches()
    super aPoint
    @layoutSubmorphs()
