class ReconfigurablePaintWdgt extends StretchableEditableWdgt

  mainCanvas: nil
  overlayCanvas: nil
  pencilToolButton: nil
  brushToolButton: nil
  toothpasteToolButton: nil
  eraserToolButton: nil
  highlightedToolIconColor: new Color 245, 126, 0


  colloquialName: ->   
    "Drawings Maker"

  representativeIcon: ->
    new PaintBucketIconWdgt()


  isToolPressed: (buttonToCheckIfPressed) ->
    whichButtonIsSelected = @toolsPanel.whichButtonSelected()
    if whichButtonIsSelected?
      if whichButtonIsSelected == buttonToCheckIfPressed.parent
        return true
      else
        return false
    return false

  # normally a button injects new code only when
  # is pressed, BUT here we make it so we inject new
  # code also if the tool is selected, without it to
  # be re-pressed. In order to do that, we
  # simply listen to a notification of new code being
  # available from a button, we check if it's selected
  # and in that case we tell the button to actually
  # inject the code.
  newCodeToInjectFromButton: (whichButtonHasNewCode) ->
    if @isToolPressed whichButtonHasNewCode
      whichButtonHasNewCode.injectCodeIntoTarget()

  createNewStretchablePanel: ->
    # mainCanvas
    @stretchableWidgetContainer = new StretchableWidgetContainerWdgt new StretchableCanvasWdgt()
    @stretchableWidgetContainer.disableDrops()
    @add @stretchableWidgetContainer

    @mainCanvas = @stretchableWidgetContainer.contents

    # overlayCanvas
    @overlayCanvas = new CanvasGlassTopWdgt()
    @overlayCanvas.underlyingCanvasMorph = @mainCanvas
    @overlayCanvas.disableDrops()
    @mainCanvas.add @overlayCanvas

    # if you clear the overlay to perfectly
    # transparent, then we need to set this flag
    # otherwise the pointer won't be reported
    # as moving inside the canvas.
    # If you give the overlay canvas even the smallest
    # tint then you don't need this flag.
    @overlayCanvas.noticesTransparentClick = true


    @overlayCanvas.injectProperty "mouseLeave", """
        # don't leave any trace behind then the pointer
        # moves out.
        (pos) ->
            context = @backBufferContext
            context.setTransform 1, 0, 0, 1, 0, 0
            context.clearRect 0, 0, @width() * pixelRatio, @height() * pixelRatio
            @changed()
    """

  createToolsPanel: ->
    @toolsPanel = new RadioButtonsHolderMorph()
    @add @toolsPanel

    pencilButtonOff = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new Pencil2IconMorph()
    pencilButtonOff.alpha = 0.1
    pencilButtonOff.sourceCodeToBeInjected = """
        mouseMove = (pos, mouseButton) ->
            if world.hand.draggingSomething() then return
            context = @backBufferContext
            context.setTransform 1, 0, 0, 1, 0, 0
            context.clearRect 0, 0, @width() * pixelRatio, @height() * pixelRatio
            context.scale pixelRatio, pixelRatio

            # give it a little bit of a tint so
            # you can see the canvas when you take it
            # apart from the paint tool.
            #context.fillStyle = (new Color 0,255,0,0.5).toString()
            #context.fillRect 0, 0, @width(), @height()

            context.translate -@bounds.origin.x, -@bounds.origin.y
            context.translate pos.x, pos.y

            context.beginPath()
            context.lineWidth="2"

            if mouseButton == 'left'
                contextMain = @underlyingCanvasMorph.getContextForPainting()
                contextMain.translate pos.x, pos.y

                contextMain.beginPath()
                contextMain.lineWidth="2"
                contextMain.fillStyle = "black"
                contextMain.rect(-2,-2,4,4)
                contextMain.fill()
                @underlyingCanvasMorph.changed()

            else
                context.strokeStyle="red"
                context.rect(-2,-2,4,4)
                context.stroke()
            @changed()
        """

    pencilButtonOn = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new Pencil2IconMorph @highlightedToolIconColor
    pencilButtonOn.alpha = 0.1
    pencilButtonOn.sourceCodeToBeInjected = "mouseMove = -> return"

    @pencilToolButton = new ToggleButtonMorph pencilButtonOff, pencilButtonOn




    brushToolButtonOff = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new BrushIconMorph()
    brushToolButtonOff.alpha = 0.1

    brushToolButtonOff.sourceCodeToBeInjected = """
        mouseMove = (pos, mouseButton) ->
            if world.hand.draggingSomething() then return
            context = @backBufferContext
            context.setTransform 1, 0, 0, 1, 0, 0
            context.clearRect 0, 0, @width() * pixelRatio, @height() * pixelRatio
            context.scale pixelRatio, pixelRatio

            context.translate -@bounds.origin.x, -@bounds.origin.y
            context.translate pos.x, pos.y

            context.beginPath()
            context.lineWidth="2"

            if mouseButton == 'left'
                context.fillStyle = "red"

                contextMain = @underlyingCanvasMorph.getContextForPainting()
                contextMain.translate pos.x, pos.y
                contextMain.fillStyle = "black"

                # the brush is 16 x 16, so center it
                contextMain.translate -8, -8

                # for convenience, the brush has been
                # drawn first using 6x6 squares, so now
                # scale those back
                contextMain.scale 1/6, 1/6

                contextMain.beginPath()
                contextMain.rect 48, 0, 6, 6
                contextMain.rect 36, 6, 6, 6
                contextMain.rect 54, 6, 6, 6
                contextMain.rect 66, 6, 6, 6
                contextMain.rect 30, 12, 12, 6
                contextMain.rect 48, 12, 6, 6
                contextMain.rect 72, 12, 6, 6
                contextMain.rect 12, 18, 36, 6
                contextMain.rect 60, 18, 6, 6
                contextMain.rect 78, 18, 6, 6
                contextMain.rect 24, 24, 42, 6
                contextMain.rect 72, 24, 6, 6
                contextMain.rect 90, 24, 6, 6
                contextMain.rect 18, 30, 42, 6
                contextMain.rect 66, 30, 6, 6
                contextMain.rect 18, 36, 36, 6
                contextMain.rect 6, 36, 6, 6
                contextMain.rect 60, 36, 12, 6
                contextMain.rect 78, 36, 6, 6
                contextMain.rect 90, 36, 6, 6
                contextMain.rect 24, 42, 36, 6
                contextMain.rect 66, 42, 12, 6
                contextMain.rect 6, 48, 6, 6
                contextMain.rect 18, 48, 6, 6
                contextMain.rect 30, 48, 12, 6
                contextMain.rect 54, 48, 6, 6
                contextMain.rect 78, 48, 6, 6
                contextMain.rect 36, 54, 6, 12
                contextMain.rect 48, 54, 6, 6
                contextMain.rect 60, 54, 12, 6
                contextMain.rect 90, 54, 6, 6
                contextMain.rect 6, 60, 6, 6
                contextMain.rect 18, 60, 12, 6
                contextMain.rect 54, 60, 6, 12
                contextMain.rect 78, 60, 6, 6
                contextMain.rect 0, 66, 6, 6
                contextMain.rect 42, 66, 6, 12
                contextMain.rect 66, 66, 6, 6
                contextMain.rect 18, 72, 6, 6
                contextMain.rect 30, 72, 6, 6
                contextMain.rect 60, 78, 6, 6
                contextMain.rect 78, 78, 6, 6
                contextMain.rect 12, 84, 6, 6
                contextMain.rect 36, 84, 6, 6
                contextMain.rect 54, 84, 6, 6
                contextMain.rect 42, 90, 6, 6
                contextMain.rect 18, 6, 6, 6
                contextMain.rect 6, 24, 6, 6
                contextMain.rect 0, 42, 6, 6
                contextMain.fill()


                @underlyingCanvasMorph.changed()

            else
                context.strokeStyle="green"
            context.rect(-5,-5,10,10)
            context.stroke()
            @changed()
        """

    brushToolButtonOn = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new BrushIconMorph @highlightedToolIconColor
    brushToolButtonOn.alpha = 0.1
    brushToolButtonOn.sourceCodeToBeInjected = "mouseMove = -> return"
    @brushToolButton = new ToggleButtonMorph brushToolButtonOff, brushToolButtonOn


    toothpasteToolButtonOff = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new ToothpasteIconMorph()
    toothpasteToolButtonOff.alpha = 0.1

    toothpasteToolButtonOff.sourceCodeToBeInjected = """
        # Toothpaste graphics
        # original implementation by Ward Cunningham, from Tektronix Smalltalk
        # implementation of Smalltalk 80
        # on the Magnolia (1980-1983) and the Tek 4404 (1984)
        # "Draw spheres ala Ken Knowlton, Computer Graphics, v15 n4 p352."

        paintBrush = (contextMain) ->
            contextMain.save()
            # the brush is 16 x 16, so center it
            contextMain.translate -8, -8

            # for convenience, the brush has been
            # drawn first using 6x6 squares, so now
            # scale those back
            contextMain.scale 1/6, 1/6

            contextMain.beginPath()
            contextMain.rect 48, 0, 6, 6
            contextMain.rect 36, 6, 6, 6
            contextMain.rect 54, 6, 6, 6
            contextMain.rect 66, 6, 6, 6
            contextMain.rect 30, 12, 12, 6
            contextMain.rect 48, 12, 6, 6
            contextMain.rect 72, 12, 6, 6
            contextMain.rect 12, 18, 36, 6
            contextMain.rect 60, 18, 6, 6
            contextMain.rect 78, 18, 6, 6
            contextMain.rect 24, 24, 42, 6
            contextMain.rect 72, 24, 6, 6
            contextMain.rect 90, 24, 6, 6
            contextMain.rect 18, 30, 42, 6
            contextMain.rect 66, 30, 6, 6
            contextMain.rect 18, 36, 36, 6
            contextMain.rect 6, 36, 6, 6
            contextMain.rect 60, 36, 12, 6
            contextMain.rect 78, 36, 6, 6
            contextMain.rect 90, 36, 6, 6
            contextMain.rect 24, 42, 36, 6
            contextMain.rect 66, 42, 12, 6
            contextMain.rect 6, 48, 6, 6
            contextMain.rect 18, 48, 6, 6
            contextMain.rect 30, 48, 12, 6
            contextMain.rect 54, 48, 6, 6
            contextMain.rect 78, 48, 6, 6
            contextMain.rect 36, 54, 6, 12
            contextMain.rect 48, 54, 6, 6
            contextMain.rect 60, 54, 12, 6
            contextMain.rect 90, 54, 6, 6
            contextMain.rect 6, 60, 6, 6
            contextMain.rect 18, 60, 12, 6
            contextMain.rect 54, 60, 6, 12
            contextMain.rect 78, 60, 6, 6
            contextMain.rect 0, 66, 6, 6
            contextMain.rect 42, 66, 6, 12
            contextMain.rect 66, 66, 6, 6
            contextMain.rect 18, 72, 6, 6
            contextMain.rect 30, 72, 6, 6
            contextMain.rect 60, 78, 6, 6
            contextMain.rect 78, 78, 6, 6
            contextMain.rect 12, 84, 6, 6
            contextMain.rect 36, 84, 6, 6
            contextMain.rect 54, 84, 6, 6
            contextMain.rect 42, 90, 6, 6
            contextMain.rect 18, 6, 6, 6
            contextMain.rect 6, 24, 6, 6
            contextMain.rect 0, 42, 6, 6
            contextMain.fill()

            contextMain.restore()

        # you'd be tempted to initialise the queue
        # on mouseDown but it would be a bad idea
        # because the mouse could come "already-pressed"
        # from outside the canvas
        initialiseQueueIfNeeded = ->
            if !@queue?
                @queue = [0..24].map -> nil

        mouseUpLeft = ->
            if world.hand.draggingSomething() then return
            if @queue?
                # draining the queue
                contextMain = @underlyingCanvasMorph.getContextForPainting()
                
                until @queue.length == 0
                    previousPos = @queue[0]
                    @queue.shift()
                    if previousPos?
                        contextMain.save()
                        contextMain.translate previousPos.x, previousPos.y
                        contextMain.fillStyle = "white"
                        @paintBrush contextMain
                        contextMain.restore()
                delete @queue

        mouseMove = (pos, mouseButton) ->
            if world.hand.draggingSomething() then return
            context = @backBufferContext
            context.setTransform 1, 0, 0, 1, 0, 0
            context.clearRect 0, 0, @width() * pixelRatio, @height() * pixelRatio
            context.scale pixelRatio, pixelRatio

            context.translate -@bounds.origin.x, -@bounds.origin.y
            context.translate pos.x, pos.y

            context.beginPath()
            context.lineWidth="2"

            if mouseButton == 'left'
                @initialiseQueueIfNeeded()
                @queue.push pos
                context.fillStyle = "red"

                contextMain = @underlyingCanvasMorph.getContextForPainting()
                
                contextMain.save()
                contextMain.translate pos.x, pos.y
                contextMain.fillStyle = "black"
                #@paintBrush contextMain
                contextMain.beginPath()
                contextMain.arc 0,0,9,0,2*Math.PI
                contextMain.fill()
                contextMain.restore()


                previousPos = @queue[0]
                @queue.shift()
                if previousPos?
                    contextMain.save()
                    contextMain.translate previousPos.x, previousPos.y
                    contextMain.fillStyle = "white"
                    @paintBrush contextMain
                    contextMain.restore()


                @underlyingCanvasMorph.changed()

            else
                context.strokeStyle="green"
            context.rect(-5,-5,10,10)
            context.stroke()
            @changed()
        """

    toothpasteToolButtonOn = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new ToothpasteIconMorph @highlightedToolIconColor
    toothpasteToolButtonOn.alpha = 0.1
    toothpasteToolButtonOn.sourceCodeToBeInjected = "mouseMove = -> return"
    @toothpasteToolButton = new ToggleButtonMorph toothpasteToolButtonOff, toothpasteToolButtonOn


    eraserToolButtonOff = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new EraserIconMorph()
    eraserToolButtonOff.alpha = 0.1

    eraserToolButtonOff.sourceCodeToBeInjected = """
        mouseMove = (pos, mouseButton) ->
            if world.hand.draggingSomething() then return
            context = @backBufferContext
            context.setTransform 1, 0, 0, 1, 0, 0
            context.clearRect 0, 0, @width() * pixelRatio, @height() * pixelRatio
            context.scale pixelRatio, pixelRatio

            context.translate -@bounds.origin.x, -@bounds.origin.y
            context.translate pos.x, pos.y

            context.beginPath()
            context.lineWidth="2"

            if mouseButton == 'left'
                context.fillStyle = "red"

                contextMain = @underlyingCanvasMorph.getContextForPainting()
                contextMain.translate pos.x, pos.y

                contextMain.beginPath()
                contextMain.lineWidth="2"
                contextMain.fillStyle = (new Color 255, 255, 255).toString()
                contextMain.rect(-5,-5,10,10)
                contextMain.fill()
                @underlyingCanvasMorph.changed()

            else
                context.strokeStyle="green"
            context.rect(-5,-5,10,10)
            context.stroke()
            @changed()
        """

    eraserToolButtonOn = new CodeInjectingSimpleRectangularButtonMorph @, @overlayCanvas, new EraserIconMorph @highlightedToolIconColor
    eraserToolButtonOn.alpha = 0.1
    eraserToolButtonOn.sourceCodeToBeInjected = "mouseMove = -> return"
    @eraserToolButton = new ToggleButtonMorph eraserToolButtonOff, eraserToolButtonOn


    pencilAnnotation = new EditableMarkMorph @pencilToolButton, pencilButtonOff, "editInjectableSource"
    brushAnnotation = new EditableMarkMorph @brushToolButton, brushToolButtonOff, "editInjectableSource"
    toothpasteAnnotation = new EditableMarkMorph @toothpasteToolButton, toothpasteToolButtonOff, "editInjectableSource"
    eraserAnnotation = new EditableMarkMorph @eraserToolButton, eraserToolButtonOff, "editInjectableSource"

    @toolsPanel.add @pencilToolButton
    @toolsPanel.add @brushToolButton
    @toolsPanel.add @toothpasteToolButton
    @toolsPanel.add @eraserToolButton

    @pencilToolButton.toggle()
    @invalidateLayout()

  reLayout: ->

    # here we are disabling all the broken
    # rectangles. The reason is that all the
    # submorphs of the inspector are within the
    # bounds of the parent Widget. This means that
    # if only the parent morph breaks its rectangle
    # then everything is OK.
    # Also note that if you attach something else to its
    # boundary in a way that sticks out, that's still
    # going to be painted and moved OK.
    trackChanges.push false

    # label
    labelLeft = @left() + @externalPadding
    labelTop = @top() + @externalPadding
    labelRight = @right() - @externalPadding
    labelWidth = labelRight - labelLeft
    labelBottom = @top() + @externalPadding

    # tools -------------------------------

    if @toolsPanel? and @toolsPanel.parent == @
        toolButtonSize = new Point 93, 55
    else
        toolButtonSize = new Point 0, 0

    eachPaneWidth = Math.floor(@width() - 2 * @externalPadding)

    if @toolsPanel? and @toolsPanel.parent == @
      eachPaneWidth -= Math.floor(@internalPadding + toolButtonSize.width())

    b = @bottom() - (2 * @externalPadding)


    if @toolsPanel? and @toolsPanel.parent == @
      @toolsPanel.fullRawMoveTo new Point @left() + @externalPadding, labelBottom
      @toolsPanel.rawSetExtent new Point 2 * @internalPadding + toolButtonSize.width(), @height() - 2 * @externalPadding

      if @pencilToolButton.parent == @toolsPanel
        buttonBounds = new Rectangle new Point @toolsPanel.left() + @internalPadding, labelBottom + @internalPadding
        buttonBounds = buttonBounds.setBoundsWidthAndHeight toolButtonSize
        @pencilToolButton.doLayout buttonBounds

      if @brushToolButton.parent == @toolsPanel
        buttonBounds = new Rectangle new Point @toolsPanel.left() + @internalPadding, @pencilToolButton.bottom() + @internalPadding
        buttonBounds = buttonBounds.setBoundsWidthAndHeight toolButtonSize
        @brushToolButton.doLayout buttonBounds

      if @toothpasteToolButton.parent == @toolsPanel
        buttonBounds = new Rectangle new Point @toolsPanel.left() + @internalPadding, @brushToolButton.bottom() + @internalPadding
        buttonBounds = buttonBounds.setBoundsWidthAndHeight toolButtonSize
        @toothpasteToolButton.doLayout buttonBounds

      if @eraserToolButton.parent == @toolsPanel
        buttonBounds = new Rectangle new Point @toolsPanel.left() + @internalPadding, @toothpasteToolButton.bottom() + @internalPadding
        buttonBounds = buttonBounds.setBoundsWidthAndHeight toolButtonSize
        @eraserToolButton.doLayout buttonBounds 

    # stretchableWidgetContainer --------------------------
    if @toolsPanel? and @toolsPanel.parent == @
      stretchableWidgetContainerWidth = @width() - @toolsPanel.width() - 2*@externalPadding - @internalPadding
    else
      stretchableWidgetContainerWidth = @width() - 2*@externalPadding

    b = @bottom() - (2 * @externalPadding)
    stretchableWidgetContainerHeight =  @height() - 2 * @externalPadding
    stretchableWidgetContainerBottom = labelBottom + stretchableWidgetContainerHeight

    if @toolsPanel? and @toolsPanel.parent == @
      stretchableWidgetContainerLeft = @toolsPanel.right() + @internalPadding
    else
      stretchableWidgetContainerLeft = @left() + @externalPadding

    if @stretchableWidgetContainer.parent == @
      @stretchableWidgetContainer.fullRawMoveTo new Point stretchableWidgetContainerLeft, labelBottom
      @stretchableWidgetContainer.setExtent new Point stretchableWidgetContainerWidth, stretchableWidgetContainerHeight


    trackChanges.pop()
    if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state != AutomatorRecorderAndPlayer.IDLE and AutomatorRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()

    @layoutIsValid = true
    @notifyChildrenThatParentHasReLayouted()

