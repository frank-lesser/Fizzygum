# REQUIRES ControllerMixin

# A multi-line, optionally word-wrapping string.
# It's not "contained": it will literally blurt itself out allover the
# screen. For "contained" text (the only practical solution for long
# text) use the SimplePlainTextWdgtScrollPanelWdgt, since that
# one... scrolls.
#
# SimplePlainTextWdgt is a compatibility layer that lets us use the new
# TextMorph2 with the current ScrollPanelWdgt and the current layout mechanism (which
# we'd want to change with a more generic one but it's a complex process).
#
# This Widget can do stuff that the TextMorph2 is not quite ready to do (i.e. can
# adjust its vertical size to fit its contents in the given width, which is what
# "normal" text editing looks like.
#
# TextMorph2 could also be used to do that, but it could do that within a larger
# layout rework that has not been done yet. Note that TextMorph2 can do a bunch more
# stuff (e.g. lets you edit in "centered" text, can fit the text to any given
# bound etc...)

class SimplePlainTextWdgt extends TextMorph2

  @augmentWith ControllerMixin

  constructor: (
   @text = "SimplePlainText",
   @originallySetFontSize = 12,
   @fontName = @justArialFontStack,
   @isBold = false,
   @isItalic = false,
   #@isNumeric = false,
   @color = (new Color 0, 0, 0),
   @backgroundColor = nil,
   @backgroundTransparency = nil
   ) ->

    super
    @silentRawSetBounds new Rectangle 0,0,400,40
    @fittingSpecWhenBoundsTooLarge = FittingSpecTextInLargerBounds.FLOAT
    @fittingSpecWhenBoundsTooSmall = FittingSpecTextInSmallerBounds.SCALEDOWN
    @maxTextWidth = true
    @reLayout()


  colloquialName: ->
    "text"

  initialiseDefaultWindowContentLayoutSpec: ->
    super
    @layoutSpecDetails.canSetHeightFreely = false

  openTargetPropertySelector: (ignored, ignored2, theTarget) ->
    [menuEntriesStrings, functionNamesStrings] = theTarget.stringSetters()
    menu = new MenuMorph @, false, @, true, true, "choose target property:"
    for i in [0...menuEntriesStrings.length]
      menu.addMenuItem menuEntriesStrings[i], true, @, "setTargetAndActionWithOnesPickedFromMenu", nil, nil, nil, nil, nil, theTarget, functionNamesStrings[i]
    if menuEntriesStrings.length == 0
      menu = new MenuMorph @, false, @, true, true, "no target properties available"
    menu.popUpAtHand()

  stringSetters: (menuEntriesStrings, functionNamesStrings) ->
    [menuEntriesStrings, functionNamesStrings] = super menuEntriesStrings, functionNamesStrings
    menuEntriesStrings.push "bang!", "text"
    functionNamesStrings.push "bang", "setText"
    return @deduplicateSettersAndSortByMenuEntryString menuEntriesStrings, functionNamesStrings

  addMorphSpecificMenuEntries: (morphOpeningThePopUp, menu) ->
    super
    menu.removeMenuItem "soft wrap"
    menu.removeMenuItem "soft wrap".tick()
    menu.removeMenuItem "soft wrap"

    menu.removeMenuItem "←☓→ don't expand to fill"
    menu.removeMenuItem "←→ expand to fill"
    menu.removeMenuItem "→← shrink to fit"
    menu.removeMenuItem "→⋯← crop to fit"

    menu.removeMenuItem "header line"
    menu.removeMenuItem "no header line"

    menu.removeMenuItem "↑ align top"
    menu.removeMenuItem "⍿ align middle"
    menu.removeMenuItem "↓ align bottom"

    menu.addLine()
    if world.isIndexPage
      menu.addMenuItem "connect to ➜", true, @, "openTargetSelector", "connect to\nanother widget"
    else
      menu.addMenuItem "set target", true, @, "openTargetSelector", "choose another morph\nwhose numerical property\n will be" + " controlled by this one"

    if @amIDirectlyInsideScrollPanelWdgt()
      childrenNotCarets = @parent.children.filter (m) ->
        !(m instanceof CaretMorph)
      if childrenNotCarets.length == 1
        menu.addLine()
        if @parent.parent.isTextLineWrapping
          menu.addMenuItem "☒ soft wrap", true, @, "softWrapOff"
        else
          menu.addMenuItem "☐ soft wrap", true, @, "softWrapOn"

    menu.removeConsecutiveLines()


  softWrapOn: ->
    @parent.parent.isTextLineWrapping = true
    @maxTextWidth = true

    @parent.fullRawMoveTo @parent.parent.position()
    @parent.rawSetExtent @parent.parent.extent()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()

  softWrapOff: ->
    @parent.parent.isTextLineWrapping = false
    @maxTextWidth = nil

    @reLayout()

    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()

  # the bang makes the node fire the current output value
  bang: (newvalue, ignored, connectionsCalculationToken, superCall) ->
    if !superCall and connectionsCalculationToken == @connectionsCalculationToken then return else if !connectionsCalculationToken? then @connectionsCalculationToken = getRandomInt -20000, 20000 else @connectionsCalculationToken = connectionsCalculationToken
    @updateTarget()

  # This is also invoked for example when you take a slider
  # and set it to target this.
  setText: (theTextContent, stringFieldMorph, connectionsCalculationToken, superCall) ->
    if !superCall and connectionsCalculationToken == @connectionsCalculationToken then return else if !connectionsCalculationToken? then @connectionsCalculationToken = getRandomInt -20000, 20000 else @connectionsCalculationToken = connectionsCalculationToken
    super theTextContent, stringFieldMorph, connectionsCalculationToken, true
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()
    @updateTarget()

  updateTarget: ->
    if @action and @action != ""
      @target[@action].call @target, @text, nil, @connectionsCalculationToken
    return

  reactToTargetConnection: ->
    @updateTarget()

  toggleShowBlanks: ->
    super
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()
  
  toggleWeight: ->
    super
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()
  
  toggleItalic: ->
    super
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()

  toggleIsPassword: ->
    super
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()

  rawSetExtent: (aPoint) ->
    super
    @reLayout()

  setFontSize: (sizeOrMorphGivingSize, morphGivingSize) ->
    super
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()

  setFontName: (ignored1, ignored2, theNewFontName) ->
    super
    @reLayout()
    @refreshScrollPanelWdgtOrVerticalStackIfIamInIt()

  blendInWithPanelColor: ->
    if @backgroundColor.eq WorldMorph.preferencesAndSettings.editableItemBackgroundColor
      @setBackgroundColor new Color 249, 249, 249

  contrastOutFromPanelColor: ->
    if @backgroundColor.eq new Color 249, 249, 249
      @setBackgroundColor WorldMorph.preferencesAndSettings.editableItemBackgroundColor

  reLayout: ->
    super()

    if @maxTextWidth? and @maxTextWidth != 0
      @softWrap = true
      [@wrappedLines,@wrappedLineSlots,@widthOfPossiblyCroppedText,@heightOfPossiblyCroppedText] =
        @breakTextIntoLines @text, @originallySetFontSize, @extent()
      width = @width()
    else
      @softWrap = false
      veryWideExtent = new Point 10000000, 10000000
      [@wrappedLines,@wrappedLineSlots,@widthOfPossiblyCroppedText,@heightOfPossiblyCroppedText] =
        @breakTextIntoLines @text, @originallySetFontSize, veryWideExtent
      width = @widthOfPossiblyCroppedText

    height = @wrappedLines.length *  Math.ceil fontHeight @originallySetFontSize
    @silentRawSetExtent new Point width, height

    @changed()
    @notifyChildrenThatParentHasReLayouted()

