class ExampleScatterPlotWdgt extends GraphsPlotsChartsWdgt


  graphNumber: 1
  drawOnlyPartOfBoundingRect: false

  constructor: (@drawOnlyPartOfBoundingRect)->
    super()
    @fps = 1
    world.addSteppingMorph @

  colloquialName: ->
    "Scatter plot"


  # This method only paints this very morph's "image",
  # it doesn't descend the children
  # recursively. The recursion mechanism is done by fullPaintIntoAreaOrBlitFromBackBuffer, which
  # eventually invokes paintIntoAreaOrBlitFromBackBuffer.
  # Note that this morph might paint something on the screen even if
  # it's not a "leaf".
  paintIntoAreaOrBlitFromBackBuffer: (aContext, clippingRectangle, appliedShadow) ->

    if @preliminaryCheckNothingToDraw clippingRectangle, aContext
      return

    [area,sl,st,al,at,w,h] = @calculateKeyValues aContext, clippingRectangle
    if area.isNotEmpty()
      if w < 1 or h < 1
        return nil

      aContext.save()

      # clip out the dirty rectangle as we are
      # going to paint the whole of the box
      aContext.clipToRectangle al,at,w,h

      aContext.globalAlpha = (if appliedShadow? then appliedShadow.alpha else 1) * @backgroundTransparency

      # paintRectangle here is made to work with
      # al, at, w, h which are actual pixels
      # rather than logical pixels, this is why
      # it's called before the scaling.
      @paintRectangle aContext, al, at, w, h, @backgroundColor
      aContext.scale pixelRatio, pixelRatio

      morphPosition = @position()
      aContext.translate morphPosition.x, morphPosition.y

      @renderingHelper aContext, new Color(255, 255, 255), appliedShadow

      aContext.restore()

      # paintHighlight here is made to work with
      # al, at, w, h which are actual pixels
      # rather than logical pixels, this is why
      # it's called outside the effect of the scaling
      # (after the restore).
      @paintHighlight aContext, al, at, w, h


  step: ->
    @graphNumber++
    @changed()

  renderingHelper: (context, color, appliedShadow) ->

    @seed = @graphNumber
    circleRadius = 5
    height = @height()
    width = @width()


    if appliedShadow?
      @simpleShadow context, color, appliedShadow
      return

    context.fillStyle = WorldMorph.preferencesAndSettings.editableItemBackgroundColor.toString()
    context.fillRect 0, 0, width, height

    availableHeight = height - 2 * circleRadius
    availableWidth = width - 2 * circleRadius

    context.globalAlpha = (if appliedShadow? then appliedShadow.alpha else 1) * @alpha

    context.lineWidth = 1

    context.beginPath()
    for i in [0...100]
      widthPerc = 0.4 + @seeded_randn_bm() / 10
      heightPerc = 0.4 + @seeded_randn_bm() / 10

      context.moveTo Math.round(2 * circleRadius + availableWidth * widthPerc),Math.round(circleRadius + availableHeight * heightPerc)
      context.arc Math.round(circleRadius + availableWidth * widthPerc),Math.round(circleRadius + availableHeight * heightPerc),circleRadius,0,2*Math.PI
    context.strokeStyle = '#325FA2'
    context.stroke()

    context.beginPath()
    for i in [0...100]
      widthPerc = 0.6 + @seeded_randn_bm() / 10
      heightPerc = 0.6 + @seeded_randn_bm() / 10

      context.moveTo Math.round(2 * circleRadius + availableWidth * widthPerc),Math.round(circleRadius + availableHeight * heightPerc)
      context.arc Math.round(circleRadius + availableWidth * widthPerc),Math.round(circleRadius + availableHeight * heightPerc),circleRadius,0,2*Math.PI

    context.strokeStyle = '#FF0000'
    context.stroke()

    @drawBoundingBox context, color, appliedShadow


