# REQUIRES HighlightableMixin
# REQUIRES ParentStainerMixin

class ItalicButtonWdgt extends Widget

  @augmentWith HighlightableMixin, @name
  @augmentWith ParentStainerMixin, @name

  color_hover: new Color 90, 90, 90
  color_pressed: new Color 128, 128, 128
  color_normal: new Color 230, 230, 230

  constructor: (@color) ->
    super
    @appearance = new ItalicIconAppearance @, WorldMorph.preferencesAndSettings.iconDarkLineColor
    @actionableAsThumbnail = true
    @editorContentPropertyChangerButton = true
    @toolTipMessage = "italic"

  mouseClickLeft: ->
    if world.lastNonTextPropertyChangerButtonClickedOrDropped?.toggleItalic?
      world.lastNonTextPropertyChangerButtonClickedOrDropped.toggleItalic()
