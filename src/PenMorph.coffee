# PenMorph ////////////////////////////////////////////////////////////

# I am a simple LOGO-wise turtle. Note that this morph's graphical
# representation is ONLY the turtle, not the graphics that come
# out of it. The graphics generated by the pan are located in the
# canvas it was attached to when the graphics happened.

class PenMorph extends Morph
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype
  
  heading: 0
  penSize: null
  isWarped: false # internal optimization
  isDown: true
  wantsRedraw: false # internal optimization
  penPoint: 'tip' # or 'center'
  
  constructor: ->
    @penSize = WorldMorph.preferencesAndSettings.handleSize * 4
    super()
    @rawSetExtent new Point(@penSize, @penSize)
    # todo we need to change the size two times, for getting the right size
    # of the arrow and of the line. Probably should make the two distinct
    @penSize = 1
    #alert @morphMethod() # works
    # doesn't work cause coffeescript doesn't support static inheritance
    #alert @morphStaticMethod()

    # no need to call  because @rawSetExtent does it.
    # (should it?)
    #


  @staticVariable: 1
  @staticFunction: -> 3.14

  imBeingAddedTo: (newParentMorph) ->
    if !(newParentMorph instanceof HandMorph or newParentMorph instanceof CanvasMorph)
      @inform "a pen will only\nwork on a canvas..."

    
  # PenMorph updating - optimized for warping, i.e atomic recursion
  changed: ->
    if @isWarped is false
      w = @root()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if w instanceof WorldMorph and (@ instanceof WorldMorph or @parent?)
        w.broken.push @clippedThroughBounds().spread()
      @parent.childChanged @  if @parent
  
  # This method only paints this very morph's "image",
  # it doesn't descend the children
  # recursively. The recursion mechanism is done by fullPaintIntoAreaOrBlitFromBackBuffer, which
  # eventually invokes paintIntoAreaOrBlitFromBackBuffer.
  # Note that this morph might paint something on the screen even if
  # it's not a "leaf".
  paintIntoAreaOrBlitFromBackBuffer: (aContext, clippingRectangle) ->

    if @preliminaryCheckNothingToDraw false, clippingRectangle, aContext
      return

    [area,sl,st,al,at,w,h] = @calculateKeyValues aContext, clippingRectangle
    if area.isNotEmpty()
      if w < 1 or h < 1
        return null

      aContext.save()

      # clip out the dirty rectangle as we are
      # going to paint the whole of the box
      aContext.clipToRectangle al,at,w,h

      aContext.globalAlpha = @alpha

      aContext.scale pixelRatio, pixelRatio
      morphPosition = @position()
      aContext.translate morphPosition.x, morphPosition.y

      direction = @heading
      if @isWarped
        @wantsRedraw = true
        return
      len = @width() / 2
      start = @center().subtract(@position())

      if @penPoint is "tip"
        dest = start.distanceAngle(len * 0.75, direction - 180)
        left = start.distanceAngle(len, direction + 195)
        right = start.distanceAngle(len, direction - 195)
      else # 'middle'
        dest = start.distanceAngle(len * 0.75, direction)
        left = start.distanceAngle(len * 0.33, direction + 230)
        right = start.distanceAngle(len * 0.33, direction - 230)

      aContext.fillStyle = @color.toString()
      aContext.beginPath()

      aContext.moveTo start.x, start.y
      aContext.lineTo left.x, left.y
      aContext.lineTo dest.x, dest.y
      aContext.lineTo right.x, right.y

      aContext.closePath()
      aContext.strokeStyle = "white"
      aContext.lineWidth = 3
      aContext.stroke()
      aContext.strokeStyle = "black"
      aContext.lineWidth = 1
      aContext.stroke()
      aContext.fill()
      @wantsRedraw = false

      aContext.restore()
      @paintHighlight aContext, al, at, w, h

  
  
  # PenMorph access:
  setHeading: (degrees) ->
    @heading = parseFloat(degrees) % 360
    @changed()
  
  
  # PenMorph drawing:
  drawLine: (start, dest) ->

    if !@parent.penTrails?
      return

    context = @parent.penTrails().getContext("2d")
    # by default penTrails() is to answer the normal
    # morph image.
    # The implication is that by default every Morph in the system
    # (including the World) is able to act as turtle canvas and can
    # display pen trails.
    # BUT also this means that pen trails will be lost whenever
    # the trail's morph (the pen's parent) performs a "drawNew()"
    # operation. If you want to create your own pen trails canvas,
    # you may wish to modify its **penTrails()** property, so that
    # it keeps a separate offscreen canvas for pen trails
    # (and doesn't lose these on redraw).

    from = start.subtract(@parent.position())
    to = dest.subtract(@parent.position())
    if @isDown
      context.lineWidth = @penSize
      context.strokeStyle = @color.toString()
      context.lineCap = "round"
      context.lineJoin = "round"
      context.beginPath()
      context.moveTo from.x, from.y
      context.lineTo to.x, to.y
      context.stroke()
      # unless we are the main desktop, then if the morph has no parent
      # don't add the broken rect since the morph is not visible
      if @isWarped is false and (@ instanceof WorldMorph or @parent?)
        world.broken.push start.rectangle(dest).expandBy(Math.max(@penSize / 2, 1)).intersect(@parent.clippedThroughBounds()).spread()
  
  
  # PenMorph turtle ops:
  turn: (degrees) ->
    @setHeading @heading + parseFloat(degrees)
  
  forward: (steps) ->
    start = @center()
    dist = parseFloat(steps)
    if dist >= 0
      dest = @position().distanceAngle(dist, @heading)
    else
      dest = @position().distanceAngle(Math.abs(dist), (@heading - 180))
    @fullRawMoveTo dest.round()
    @drawLine start, @center()
  
  down: ->
    @isDown = true
  
  up: ->
    @isDown = false
  
  clear: ->
    
    @parent.changed()
  
  
  # PenMorph optimization for atomic recursion:
  startWarp: ->
    @wantsRedraw = false
    @isWarped = true
  
  endWarp: ->
    @isWarped = false
    if @wantsRedraw
      
      @wantsRedraw = false
    @parent.changed()
  
  warp: (fun) ->
    @startWarp()
    fun.call @
    @endWarp()
  
  warpOp: (selector, argsArray) ->
    @startWarp()
    @[selector].apply @, argsArray
    @endWarp()
  
  
  # PenMorph demo ops:
  # try these with WARP eg.: this.warp(function () {tree(12, 120, 20)})
  warpSierpinski: (length, min) ->
    @warpOp "sierpinski", [length, min]
  
  sierpinski: (length, min) ->
    if length > min
      for i in [0...3]
        @sierpinski length * 0.5, min
        @turn 120
        @forward length
  
  warpTree: (level, length, angle) ->
    @warpOp "tree", [level, length, angle]
  
  tree: (level, length, angle) ->
    if level > 0
      @penSize = level
      @forward length
      @turn angle
      @tree level - 1, length * 0.75, angle
      @turn angle * -2
      @tree level - 1, length * 0.75, angle
      @turn angle
      @forward -length
