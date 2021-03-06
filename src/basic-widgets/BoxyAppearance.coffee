class BoxyAppearance extends Appearance

  getCornerRadius: ->
    if @morph.cornerRadius?
      return @morph.cornerRadius
    else
      return 4

  constructor: (morph) ->
    super morph

  isTransparentAt: (aPoint) ->
    # first quickly check if the point is even
    # within the bounding box
    if !@morph.boundsContainPoint aPoint
      return true
 
    thisMorphPosition = @morph.position()
    radius = Math.max @getCornerRadius(), 0
 
    relativePoint = new Point aPoint.x - thisMorphPosition.x, aPoint.y - thisMorphPosition.y

    # top left corner
    if relativePoint.x < radius and relativePoint.y < radius
      if relativePoint.distanceTo(new Point radius,radius) > radius
        return true

    # top right corner
    else if relativePoint.x > @morph.width() - radius and relativePoint.y < radius
      if relativePoint.distanceTo(new Point @morph.width() - radius,radius) > radius
        return true

    # bottom left corner
    else if relativePoint.x < radius and relativePoint.y > @morph.height() - radius
      if relativePoint.distanceTo(new Point radius, @morph.height() - radius) > radius
        return true

    # bottom right corner
    else if relativePoint.x > @morph.width() - radius and relativePoint.y > @morph.height() - radius
      if relativePoint.distanceTo(new Point @morph.width() - radius, @morph.height() - radius) > radius
        return true


    return false
  
  # This method only paints this very morph's "image",
  # it doesn't descend the children
  # recursively. The recursion mechanism is done by fullPaintIntoAreaOrBlitFromBackBuffer, which
  # eventually invokes paintIntoAreaOrBlitFromBackBuffer.
  # Note that this morph might paint something on the screen even if
  # it's not a "leaf".
  paintIntoAreaOrBlitFromBackBuffer: (aContext, clippingRectangle, appliedShadow) ->

    if @morph.preliminaryCheckNothingToDraw clippingRectangle, aContext
      return nil

    [area,sl,st,al,at,w,h] = @morph.calculateKeyValues aContext, clippingRectangle
    if area.isNotEmpty()
      if w < 1 or h < 1
        return nil

      aContext.save()

      # clip out the dirty rectangle as we are
      # going to paint the whole of the box
      aContext.clipToRectangle al,at,w,h

      aContext.globalAlpha = (if appliedShadow? then appliedShadow.alpha else 1) * @morph.alpha

      aContext.scale pixelRatio, pixelRatio
      morphPosition = @morph.position()
      aContext.translate morphPosition.x, morphPosition.y
      aContext.fillStyle = @morph.color.toString()
      
      if appliedShadow?
        aContext.fillStyle = "black"

      aContext.beginPath()
      @outlinePath aContext, Math.max @getCornerRadius(), false
      aContext.closePath()
      aContext.fill()

      if @morph.strokeColor? and !appliedShadow?
        aContext.lineWidth = 1
        aContext.strokeStyle = @morph.strokeColor.toString()
        aContext.beginPath()
        @outlinePath aContext, Math.max @getCornerRadius(), true
        aContext.closePath()
        aContext.stroke()

      aContext.restore()

      # paintHighlight is usually made to work with
      # al, at, w, h which are actual pixels
      # rather than logical pixels, so it's generally used
      # outside the effect of the scaling because
      # of the pixelRatio (i.e. after the restore)
      @paintHighlight aContext, al, at, w, h

  
  outlinePath: (context, radius, isStroke) ->
    offset = radius
    # in order to be crisp, strokes have to be displaced a bit
    # (while fills don't, they'd look fuzzy instead)
    if isStroke
      offset += 0.5
    w = @morph.width()
    h = @morph.height()
    # top left:
    context.arc offset, offset, radius, degreesToRadians(-180), degreesToRadians(-90)
    # top right:
    context.arc w - offset, offset, radius, degreesToRadians(-90), degreesToRadians(-0)
    # bottom right:
    context.arc w - offset, h - offset, radius, degreesToRadians(0), degreesToRadians(90)
    # bottom left:
    context.arc offset, h - offset, radius, degreesToRadians(90), degreesToRadians(180)

  cornerRadiusPopout: (menuItem)->
    @morph.prompt menuItem.parent.title + "\ncorner\nradius:",
      @morph,
      "setCornerRadius",
      @morph.cornerRadius.toString(),
      nil,
      0,
      100,
      true
  
  # Boxy menus:
  addShapeSpecificMenuItems: (menu) ->
    menu.addLine()
    menu.addMenuItem "corner radius...", true, @, "cornerRadiusPopout", "set the corner's\nradius"
    menu.addMenuItem "pick inset...", true, @morph, "pickInset", "put a morph as inset"
    menu
  
  addShapeSpecificNumericalSetters: (menuEntriesStrings, functionNamesStrings) ->
    if !menuEntriesStrings? 
      menuEntriesStrings = []
      functionNamesStrings = []
    menuEntriesStrings.push "corner radius"
    functionNamesStrings.push "setCornerRadius"
    return @deduplicateSettersAndSortByMenuEntryString menuEntriesStrings, functionNamesStrings
