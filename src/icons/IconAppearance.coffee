# REQUIRES Point

class IconAppearance extends Appearance

  # preferredSize and specificationSize should be
  # in the same ratio
  preferredSize: new Point 200, 200

  # this is the dimension of the "original" canvas
  # that the actual code paints on.
  specificationSize: new Point 200, 200

  # default icon is a circle
  paintFunction: (context) ->
    fillColor = @color
    context.beginPath()
    context.moveTo 100.5, 7
    context.bezierCurveTo 50.05, 7, 9, 48.04, 9, 98.5
    context.bezierCurveTo 9, 148.95, 50.05, 190, 100.5, 190
    context.bezierCurveTo 150.95, 190, 192, 148.95, 192, 98.5
    context.bezierCurveTo 192, 48.04, 150.95, 7, 100.5, 7
    context.closePath()
    context.moveTo 100.5, 20.39
    context.bezierCurveTo 143.72, 20.39, 178.61, 55.28, 178.61, 98.5
    context.bezierCurveTo 178.61, 141.72, 143.72, 176.61, 100.5, 176.61
    context.bezierCurveTo 57.28, 176.61, 22.39, 141.72, 22.39, 98.5
    context.bezierCurveTo 22.39, 55.28, 57.28, 20.39, 100.5, 20.39
    context.closePath()
    context.fillStyle = fillColor.toString()
    context.fill()




  calculateRectangleOfIcon: ->
    height = @morph.height()
    width = @morph.width()

    scaleW = Math.abs(width / @preferredSize.width())
    scaleH = Math.abs(height / @preferredSize.height())


    # default: stretch
    # nothing to do


    # aspect fit
    scaleW = Math.min(scaleW, scaleH)
    scaleH = scaleW

    # aspect fill
    #scaleW = Math.max(scaleW, scaleH)
    #scaleH = scaleW

    # center
    #scaleW = 1
    #scaleH = 1

    result = new Rectangle(Math.min(0, @preferredSize.width()), Math.min(0, @preferredSize.height()), Math.abs(@preferredSize.width()), Math.abs(@preferredSize.height()))
    result2W = result.width() * scaleW
    result2H = result.height() * scaleH
    result2X = @morph.left() + (width - (result2W)) / 2
    result2Y = @morph.top() + (height - (result2H)) / 2

    result = new Rectangle result2X, result2Y, result2X + result2W, result2Y + result2H
    return result.round()

  widthWithoutSpacing: ->
    @calculateRectangleOfIcon().width()

  # This method only paints this very morph's "image",
  # it doesn't descend the children
  # recursively. The recursion mechanism is done by fullPaintIntoAreaOrBlitFromBackBuffer, which
  # eventually invokes paintIntoAreaOrBlitFromBackBuffer.
  # Note that this morph might paint something on the screen even if
  # it's not a "leaf".
  paintIntoAreaOrBlitFromBackBuffer: (aContext, clippingRectangle, appliedShadow) ->
    if @morph.preliminaryCheckNothingToDraw clippingRectangle, aContext
      return

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
      #aContext.translate morphPosition.x, morphPosition.y
      #debugger

      result = @calculateRectangleOfIcon()


      aContext.translate(result.left(), result.top())
      aContext.scale(result.width() / @preferredSize.width(), result.height() / @preferredSize.height())
      aContext.scale(@preferredSize.width() / @specificationSize.width(), @preferredSize.height() / @specificationSize.height())

      ## at this point, you draw in a squareSize x squareSize
      ## canvas, and it gets painted in a square that fits
      ## the morph, right in the middle.
      @paintFunction aContext

      aContext.restore()

      # paintHighlight is usually made to work with
      # al, at, w, h which are actual pixels
      # rather than logical pixels, so it's generally used
      # outside the effect of the scaling because
      # of the pixelRatio (i.e. after the restore)
      #@paintHighlight aContext, al, at, w, h

  oval: (context, x, y, w, h) ->
    context.save()
    context.beginPath()
    context.translate x, y
    context.scale w / 2, h / 2
    context.arc 1, 1, 1, 0, 2 * Math.PI
    context.closePath()
    context.restore()
    return

  arc: (context, x, y, w, h, startAngle, endAngle, isClosed) ->
    context.save()
    context.beginPath()
    context.translate x, y
    context.scale w / 2, h / 2
    context.arc 1, 1, 1, Math.PI / 180 * startAngle, Math.PI / 180 * endAngle
    if isClosed
      context.lineTo 1, 1
      context.closePath()
    context.restore()
    return


