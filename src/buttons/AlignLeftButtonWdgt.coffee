# REQUIRES HighlightableMixin
# REQUIRES ParentStainerMixin

class AlignLeftButtonWdgt extends Widget

  @augmentWith HighlightableMixin, @name
  @augmentWith ParentStainerMixin, @name

  color_hover: new Color 90, 90, 90
  color_pressed: new Color 128, 128, 128
  color_normal: new Color 230, 230, 230

  constructor: (@color) ->
    super
    @appearance = new AlignLeftIconAppearance @, WorldMorph.preferencesAndSettings.iconDarkLineColor
    @actionableAsThumbnail = true
    @editorContentPropertyChangerButton = true
    @toolTipMessage = "align left"

  mouseClickLeft: ->
    if world.lastNonTextPropertyChangerButtonClickedOrDropped?.alignLeft?
      world.lastNonTextPropertyChangerButtonClickedOrDropped.alignLeft()
    else if world.lastNonTextPropertyChangerButtonClickedOrDropped?
      lastNonTextPropertyChangerButtonClickedOrDropped = world.lastNonTextPropertyChangerButtonClickedOrDropped.findRootForGrab()
      if lastNonTextPropertyChangerButtonClickedOrDropped?.layoutSpec? and
       lastNonTextPropertyChangerButtonClickedOrDropped.layoutSpec == LayoutSpec.ATTACHEDAS_VERTICAL_STACK_ELEMENT
        lastNonTextPropertyChangerButtonClickedOrDropped.layoutSpecDetails.setAlignmentToLeft()


