class DashboardsWdgt extends StretchableEditableWdgt

  colloquialName: ->   
    "Dashboards Maker"

  representativeIcon: ->
    new DashboardsIconWdgt()


  createToolsPanel: ->
    # tools -------------------------------
    @toolsPanel = new ScrollPanelWdgt new ToolPanelWdgt()

    @toolsPanel.addMany [
      new TextBoxCreatorButtonWdgt()
      new ExternalLinkCreatorButtonWdgt()

      new ScatterPlotWithAxesCreatorButtonWdgt()
      new FunctionPlotWithAxesCreatorButtonWdgt()
      new BarPlotWithAxesCreatorButtonWdgt()
      new Plot3DCreatorButtonWdgt()

      new WorldMapCreatorButtonWdgt()
      new USAMapCreatorButtonWdgt()
      new MapPinIconWdgt()

      new SpeechBubbleWdgt()

      new ArrowNIconWdgt()
      new ArrowSIconWdgt()
      new ArrowWIconWdgt()
      new ArrowEIconWdgt()
      new ArrowNWIconWdgt()
      new ArrowNEIconWdgt()
      new ArrowSWIconWdgt()
      new ArrowSEIconWdgt()
    ]



    @toolsPanel.disableDragsDropsAndEditing()
    @add @toolsPanel
    @dragsDropsAndEditingEnabled = true
    @invalidateLayout()

  createNewStretchablePanel: ->
    @stretchableWidgetContainer = new StretchableWidgetContainerWdgt()
    @add @stretchableWidgetContainer


  # TODO this method is the same as in the simple slide widget
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

    b = @bottom() - (2 * @externalPadding)

    if @toolsPanel?.parent == @
      @toolsPanel.fullRawMoveTo new Point @left() + @externalPadding, labelBottom
      @toolsPanel.rawSetExtent new Point 95, @height() - 2 * @externalPadding


    # stretchableWidgetContainer --------------------------

    stretchableWidgetContainerWidth = @width() - 2*@externalPadding
    
    if @dragsDropsAndEditingEnabled
      stretchableWidgetContainerWidth -= @toolsPanel.width() + @internalPadding

    b = @bottom() - (2 * @externalPadding)
    stretchableWidgetContainerHeight =  @height() - 2 * @externalPadding
    stretchableWidgetContainerBottom = labelBottom + stretchableWidgetContainerHeight
    if @dragsDropsAndEditingEnabled
      stretchableWidgetContainerLeft = @toolsPanel.right() + @internalPadding
    else
      stretchableWidgetContainerLeft = @left() + @externalPadding

    if @stretchableWidgetContainer.parent == @
      @stretchableWidgetContainer.fullRawMoveTo new Point stretchableWidgetContainerLeft, labelBottom
      @stretchableWidgetContainer.setExtent new Point stretchableWidgetContainerWidth, stretchableWidgetContainerHeight

    # ----------------------------------------------


    trackChanges.pop()
    if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state != AutomatorRecorderAndPlayer.IDLE and AutomatorRecorderAndPlayer.alignmentOfMorphIDsMechanism
      world.alignIDsOfNextMorphsInSystemTests()

    @layoutIsValid = true
    @notifyChildrenThatParentHasReLayouted()


