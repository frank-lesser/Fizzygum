class GrayscalePaletteNodeCreatorButtonWdgt extends CreatorButtonWdgt

  constructor: ->
    super
    @appearance = new GrayscalePalettePatchProgrammingIconAppearance @, WorldMorph.preferencesAndSettings.iconDarkLineColor
    @toolTipMessage = "grayscale palette"

  createWidgetToBeHandled: ->
    switcherooWm = new WindowWdgt nil, nil, new GrayPaletteMorph(), true
    switcherooWm.rawSetExtent new Point 200, 200
    return switcherooWm


