# The mouse cursor. Note that it's not a child of the WorldMorph, this Widget
# is never added to any other morph. [TODO] Find out why and write explanation.
# Not to be confused with the HandleMorph

class HandMorph extends Widget

  world: nil
  mouseButton: nil
  # used for example to check that
  # mouseDown and mouseUp happen on the
  # same Widget (otherwise clicks happen for
  # example when resizing a button via the
  # handle)
  mouseDownMorph: nil
  mouseDownPosition: nil
  morphToGrab: nil
  grabOrigin: nil
  mouseOverList: nil
  toolTipsList: nil
  touchHoldTimeout: nil
  doubleClickMorph: nil
  tripleClickMorph: nil
  nonFloatDraggedMorph: nil
  nonFloatDragPositionWithinMorphAtStart: nil
  # this is useful during nonFloatDrags to pass the morph
  # the delta position since the last invokation
  previousNonFloatDraggingPos: nil

  constructor: (@world) ->
    @mouseOverList = []
    @toolTipsList = []
    super()
    @minimumExtent = new Point 0,0
    @silentRawSetBounds Rectangle.EMPTY

  clippedThroughBounds: ->
    @checkClippedThroughBoundsCache = WorldMorph.numberOfAddsAndRemoves + "-" + WorldMorph.numberOfVisibilityFlagsChanges + "-" + WorldMorph.numberOfCollapseFlagsChanges + "-" + WorldMorph.numberOfRawMovesAndResizes
    @clippedThroughBoundsCache = @boundingBox()
    return @clippedThroughBoundsCache

  clipThrough: ->
    @checkClipThroughCache = WorldMorph.numberOfAddsAndRemoves + "-" + WorldMorph.numberOfVisibilityFlagsChanges + "-" + WorldMorph.numberOfCollapseFlagsChanges + "-" + WorldMorph.numberOfRawMovesAndResizes
    @clipThroughCache = @boundingBox()
    return @clipThroughCache
  
  # HandMorph navigation:
  topMorphUnderPointer: ->
    result = @world.topMorphSuchThat (m) =>
      m.clippedThroughBounds().containsPoint(@position()) and
        m.visibleBasedOnIsVisibleProperty() and
        !m.isCollapsed() and
        (m.noticesTransparentClick or (not m.isTransparentAt(@position()))) and
        # we exclude the Caret here because
        #  a) it messes up things on double-click as it appears under
        #     the mouse after the first clicks
        #  b) the caret disappears as soon as a menu appears, so it
        #     would be confusing to select a caret.
        # I drafted an alternative implementation where we manage
        # those situations without being radical in this filtering-out
        # but it was quite a bit more complicated.
        (m not instanceof CaretMorph) and
        # exclude morphs we use for highlighting
        # other morphs
        !m.morphThisMorphIsHighlighting? and
        !m.morphThisMorphIsPinouting?
    if result?
      return result
    else
      return @world

  menuAtPointer: ->
    result = @world.topMorphSuchThat (m) =>
      m.clippedThroughBounds().containsPoint(@position()) and
        m.visibleBasedOnIsVisibleProperty() and
        !m.isCollapsed() and
        (m.noticesTransparentClick or
        (not m.isTransparentAt(@position()))) and (m instanceof MenuMorph)
    return result



  openContextMenuAtPointer: (morphTheMenuIsAbout) ->
    # note that the morphs that the menu
    # belongs to might not be under the mouse.
    # It usually is, but in cases
    # where a system test is playing against
    # a world setup that has varied since the
    # recording, this could be the case.

    # these three are checks and actions that normally
    # would happen on MouseDown event, but we
    # removed that event as we collapsed the down and up
    # into this coalesced higher-level event,
    # but we still need to make these checks and actions
    @destroyTemporaryHandlesAndLayoutAdjustersIfHandHasNotActionedThem morphTheMenuIsAbout
    @stopEditingIfWidgetDoesntNeedCaretOrActionIsElsewhere morphTheMenuIsAbout

    if AutomatorRecorderAndPlayer? and
     AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
      fade 'rightMouseButtonIndicator', 0, 1, 10, new Date().getTime()
      setTimeout \
        =>
          fade 'rightMouseButtonIndicator', 1, 0, 500, new Date().getTime()
        , 100
    
    contextMenu = morphTheMenuIsAbout.buildContextMenu()
    while !contextMenu and morphTheMenuIsAbout.parent
      morphTheMenuIsAbout = morphTheMenuIsAbout.parent
      contextMenu = morphTheMenuIsAbout.buildContextMenu()

    if contextMenu
      contextMenu.popUpAtHand()


  # not used in ZK yet
  allMorphsAtPointer: ->
    return @world.collectAllChildrenBottomToTopSuchThat (m) =>
      m.visibleBasedOnIsVisibleProperty() and
      !m.isCollapsed() and
      m.clippedThroughBounds().containsPoint @position()
  
  
  
  # HandMorph floatDragging and dropping:
  #
  # floatDrag 'n' drop events, method(arg) -> receiver:
  #
  #   prepareToBeGrabbed() -> grabTarget
  #   reactToGrabOf(grabbedMorph) -> oldParent
  #   wantsDropOf(morphToDrop) ->  newParent
  #   justDropped(handMorph) -> droppedMorph
  #   reactToDropOf(droppedMorph, handMorph) -> newParent
  #
  dropTargetFor: (aMorph) ->
    target = @topMorphUnderPointer()
    until target.wantsDropOf aMorph
      target = target.parent
    target
  
  grab: (aMorph, displacementDueToGrabDragThreshold,  switcherooHappened) ->
    return nil  if aMorph instanceof WorldMorph
    oldParent = aMorph.parent
    if !@floatDraggingSomething()

      if AutomatorRecorderAndPlayer?
        @world.automatorRecorderAndPlayer.addGrabCommand()
        if AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.RECORDING
          action = "grab"
          arr = window.world.automatorRecorderAndPlayer.tagsCollectedWhileRecordingTest
          if action not in arr
            arr.push action


      @world.stopEditing()

      # this paragraph deals with how to resize/reposition the widget
      # that we are grabbing in respect to the hand
      if switcherooHappened
        # in this case the widget being grabbed is created on the fly
        # so just like the next case it's OK to center it under the pointer
        aMorph.fullRawMoveTo @position().subtract aMorph.extent().floorDivideBy 2
        aMorph.fullRawMoveWithin world
      else if aMorph.extentToGetWhenDraggedFromGlassBox? and (oldParent instanceof GlassBoxBottomWdgt)
        # in this case the widget is "inflating". So, all
        # visual references that the user might have around the
        # position of the grab go out of the window: just center
        # the widget under the pointer and fit it within the
        # desktop bounds since we are at it (useful in case the
        # widget is inflating near the screen edges)
        aMorph.rawSetExtent aMorph.extentToGetWhenDraggedFromGlassBox
        aMorph.fullRawMoveTo @position().subtract aMorph.extent().floorDivideBy 2
        aMorph.fullRawMoveWithin world
      else if displacementDueToGrabDragThreshold?
        # in this case keep some visual consistency and move
        # the widget accordingly to where the grab started
        # (remember: we actually grab a while after the user has
        # pressed, because we want to see an actual significant move
        # before we resolve that this is a grab)
        # Don't fit the widget within the world because it often
        # happens to pick up a widget that is partially outside the
        # screen and it's no good to make it jump within the screen
        # - I tried and it looks really strange -
        aMorph.fullMoveTo aMorph.position().add displacementDueToGrabDragThreshold

      @grabOrigin = aMorph.situation()
      aMorph.prepareToBeGrabbed?()

      @add aMorph
      aMorph.justBeenGrabbed? oldParent
      # you must add the shadow
      # after the morph has been added
      # because "@add aMorph" causes
      # the morph to be painted potentially
      # for the first time.
      # The shadow needs the image of the
      # morph to make the shadow, so
      # this is why we add the shadow after
      # the morph has been added.
      # Note that Widgets can specify the look
      # (i.e. offset blur and color)
      # of their shadow (e.g. Menus have a particular one
      # so they all seem to float at a particular height)
      # but here when we grab morphs we
      # specify a particular look for the shadow.
      # This is a particularly "floaty" shadow
      # which illustrates how things being dragged
      # are above anything else.

      aMorph.addShadow new Point(6, 6), 0.1
      
      #debugger
      @fullChanged()
      # this gives an occasion to the old parent
      # morph to adjust itself e.g. the ScrollPanelWdgt
      # readjusts itself if you take some morphs
      # out of it.
      oldParent?.reactToGrabOf? aMorph

  draggingSomething: ->
    @floatDraggingSomething() or @nonFloatDraggingSomething()

  floatDraggingSomething: ->
    if @children.length > 0 then true else false

  nonFloatDraggingSomething: ->
    return @nonFloatDraggedMorph?


  drop: ->
    if @floatDraggingSomething()

      if AutomatorRecorderAndPlayer?
        @world.automatorRecorderAndPlayer.addDropCommand()
        if AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.RECORDING
          action = "drop"
          arr = window.world.automatorRecorderAndPlayer.tagsCollectedWhileRecordingTest
          if action not in arr
            arr.push action

      morphToDrop = @children[0]

      if morphToDrop.rejectsBeingDropped?()
        target = world
      else
        target = @dropTargetFor morphToDrop

      @fullChanged()
      morphToDrop.aboutToBeDropped? target
      target.aboutToDrop? morphToDrop
      target.add morphToDrop, nil, nil, true, nil, @position()
      morphToDrop.fullChanged()

      # when you click the buttons, sometimes you end up
      # clicking between the buttons, and so the "proper"
      # widget "loses focus" so to speak. So avoiding that here.
      if !(morphToDrop instanceof HorizontalMenuPanelWdgt)
        world.lastNonTextPropertyChangerButtonClickedOrDropped = morphToDrop

      @children = []
      @rawSetExtent new Point()

      # first we notify the recipient of the drop
      # this gives the chance to the recipient to
      # initialise a layout spec for the dropped widget
      target.reactToDropOf? morphToDrop, @

      # then we notify the dropped widget. This currently
      # is used to let the dropped morph tweak the layout
      # spec (some widgets suddenly become constrained by ratio
      # when they are dropped into a document)
      morphToDrop.justDropped? target

    #else
    #  alert "if you never see this alert then you can delete the test"
  
  # HandMorph event dispatching:
  #
  #    mouse events:
  #
  #   mouseDownLeft
  #   mouseDownRight
  #   mouseClickLeft
  #   mouseClickRight
  #   mouseDoubleClick
  #   mouseEnter
  #   mouseLeave
  #   mouseEnterfloatDragging
  #   mouseLeavefloatDragging
  #   mouseMove
  #   wheel
  #
  # Note that some handlers don't want the event but the
  # interesting parameters of the event. This is because
  # the testing harness only stores the interesting parameters
  # rather than a multifaceted and sometimes browser-specific
  # event object.

  destroyTemporaryHandlesAndLayoutAdjustersIfHandHasNotActionedThem: (actionedMorph) ->
    if @world.temporaryHandlesAndLayoutAdjusters.length > 0
      if actionedMorph not in @world.temporaryHandlesAndLayoutAdjusters
        for eachTemporaryHandlesAndLayoutAdjusters in @world.temporaryHandlesAndLayoutAdjusters
          eachTemporaryHandlesAndLayoutAdjusters.fullDestroy()
        @world.temporaryHandlesAndLayoutAdjusters = []

  stopEditingIfWidgetDoesntNeedCaretOrActionIsElsewhere: (actionedMorph) ->
    if @world.caret?

      # some actioning widgets rely on the
      # caret, for example to change the properties
      # of text (e.g. make it bold)
      if actionedMorph.editorContentPropertyChangerButton? and actionedMorph.editorContentPropertyChangerButton
        return

      # if you click anything directly inside a button that has
      # "editorContentPropertyChangerButton" set, then do nothing
      # This is needed because you might "down" on the label of the
      # button and you don't want to stopEditing in that case
      # either...
      if actionedMorph.parent? and
       (actionedMorph.parent instanceof SimpleButtonMorph) and
       actionedMorph.parent.editorContentPropertyChangerButton? and
       actionedMorph.parent.editorContentPropertyChangerButton
        return

      # there is a caret on the screen
      # depending on what the user is clicking on,
      # we might need to close an ongoing edit
      # operation, which means deleting the
      # caret and un-selecting anything that was selected.
      #
      # This check is because we don't want to interrupt
      # an edit if the user is invoking/clicking on anything
      # inside a menu regarding text that is being edited
      # because the invoked function
      # might do something with the selection
      # (for example doSelection takes the current selection).
      #
      # In other words, if we are actioning on something that has
      # the text as an ancestor, then don't stop the
      # editing.
      if actionedMorph isnt @world.caret.target
        # user clicked on something other than what the
        # caret is attached to
        mostRecentlyCreatedPopUp = world.mostRecentlyCreatedPopUp()
        if mostRecentlyCreatedPopUp?
          unless mostRecentlyCreatedPopUp.isAncestorOf actionedMorph
            # only dismiss editing if the actionedMorph the user
            # clicked on is not part of a menu.
            @world.stopEditing()
        # there is no menu at all, in which case
        # we know there was an editing operation going
        # on that we need to stop
        else
          @world.stopEditing()


  processMouseDown: (button, buttons, ctrlKey, shiftKey, altKey, metaKey) ->
    @destroyToolTips()
    @morphToGrab = nil

    if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
      if button is 2 or ctrlKey
        fade 'rightMouseButtonIndicator', 0, 1, 10, new Date().getTime()
      else
        fade 'leftMouseButtonIndicator', 0, 1, 10, new Date().getTime()


    @mouseDownPosition = @position()

    # check whether we are in the middle
    # of a floatDrag/drop operation
    if @floatDraggingSomething()
      @drop()
      @mouseButton = nil
    else
      morph = @topMorphUnderPointer()

      @destroyTemporaryHandlesAndLayoutAdjustersIfHandHasNotActionedThem morph
      # TODO it seems a little aggressive to stop any editing
      # just on the "down", probably something higher level
      # would be better? Like if any other object is brought to the
      # foreground?
      @stopEditingIfWidgetDoesntNeedCaretOrActionIsElsewhere morph

      # if we are doing a mousedown on anything outside a menu
      # then all the menus must go, whether or not they have
      # been freshly created or not. This came about because
      # small movements of the mouse while clicking on the
      # desktop would not dismiss menus.
      if !(morph.firstParentThatIsAPopUp() instanceof MenuMorph)
        @cleanupMenuMorphs nil, morph, true

      @morphToGrab = morph.findRootForGrab()
      if button is 2 or ctrlKey
        @mouseButton = "right"
        actualClick = "mouseDownRight"
        expectedClick = "mouseClickRight"
      else
        @mouseButton = "left"
        actualClick = "mouseDownLeft"
        expectedClick = "mouseClickLeft"

      @mouseDownMorph = morph
      @mouseDownMorph = @mouseDownMorph.parent  until @mouseDownMorph[expectedClick]

      
      while !morph[actualClick]?
        if morph.parent?
          morph = morph.parent
        else
          break

      if morph[actualClick]?
        morph[actualClick] @position()
      #morph = morph.parent  until morph[actualClick]
      #morph[actualClick] @position()
  
  # touch events, see:
  # https://developer.apple.com/library/safari/documentation/appleapplications/reference/safariwebcontent/HandlingEvents/HandlingEvents.html
  # A long touch emulates a right click. This is done via
  # setting a timer 400ms after the touch which triggers
  # a right mouse click. Any touch event before then just
  # resets the timer (if far enough from the touch start point,
  # to "de-noise" the hold).
  processTouchStart: (event) ->
    #WorldMorph.preferencesAndSettings.isTouchDevice = true
    clearInterval @touchHoldTimeout
    if event.touches.length is 1
      # simulate mouseRightClick
      touch = event.touches[0]
      @touchStartPosition = new Point touch.pageX, touch.pageY
      @touchHoldTimeout = setInterval(=>
        @processMouseDown 2 # button 2 is the right one
        @processMouseUp 2 # button 2 is the right one, we don't use this parameter
        event.preventDefault() # I don't think that this is needed
        clearInterval @touchHoldTimeout
      , 400)
      @processMouseMove touch.pageX, touch.pageY # update my position
      @processMouseDown 0 # button zero is the left button
  
  processTouchMove: (event) ->
    if event.touches.length is 1
      touch = event.touches[0]
      @processMouseMove touch.pageX, touch.pageY
      if ((new Point touch.pageX, touch.pageY).distanceTo @touchStartPosition) > WorldMorph.preferencesAndSettings.grabDragThreshold
        clearInterval @touchHoldTimeout

  processTouchEnd: (event) ->
    # note that the mouse down event handler
    # that is calling this method has ALREADY
    # added a mousedown command

    #WorldMorph.preferencesAndSettings.isTouchDevice = true
    clearInterval @touchHoldTimeout
    @processMouseUp 0 # button zero is the left button, we don't use this parameter
    
    # no need to set this to nil, but let's just clean up
    @touchStartPosition = nil
  
   # note that the button param is not used,
   # but adding it for consistency...
  processMouseUp: (button, buttons, ctrlKey, shiftKey, altKey, metaKey) ->
    if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
      if button is 2
        fade 'rightMouseButtonIndicator', 1, 0, 500, new Date().getTime()
      else
        fade 'leftMouseButtonIndicator', 1, 0, 500, new Date().getTime()

    morph = @topMorphUnderPointer()

    alreadyRecordedLeftOrRightClickOnMenuItem = false
    @destroyToolTips()
    world.freshlyCreatedPopUps = []


    if @floatDraggingSomething()
      @drop()
    else

      # used right now for the slider button:
      # it's likely that the non-float drag will end
      # up outside of its bounds, and yet we need to
      # notify the button that the drag is over so it
      # can repaint itself of another color.
      if @nonFloatDraggingSomething()
        @nonFloatDraggedMorph.endOfNonFloatDrag?()

      @previousNonFloatDraggingPos = nil
      # let's check if the user clicked on a menu item,
      # in which case we add a special dedicated command
      # [TODO] you need to do some of this only if you
      # are recording a test, it's worth saving
      # these steps...
      #debugger
      ignored = nil
      toDestructure = morph.parentThatIsA MenuItemMorph
      if toDestructure?
        [menuItemMorph, ignored]= toDestructure
        if menuItemMorph
          # we check whether the menuitem is actually part
          # of an activeMenu. Keep in mind you could have
          # detached a menuItem and placed it on any other
          # morph so you need to ascertain that you'll
          # find it in the activeMenu later on...
          mostRecentlyCreatedPopUp = world.mostRecentlyCreatedPopUp()
          if mostRecentlyCreatedPopUp == menuItemMorph.parent
            labelString = menuItemMorph.labelString
            occurrenceNumber = menuItemMorph.howManySiblingsBeforeMeSuchThat (m) ->
              m.labelString == labelString
            # this method below is also going to remove
            # the mouse down/up commands that have
            # recently/just been added.
            if AutomatorRecorderAndPlayer?
              @world.automatorRecorderAndPlayer.addCommandLeftOrRightClickOnMenuItem(@mouseButton, labelString, occurrenceNumber + 1)
            alreadyRecordedLeftOrRightClickOnMenuItem = true

      # TODO check if there is any other
      # possibility other than mouseButton being "left"
      # or "right". If it can only be one of those
      # that you can simplify this nested if below
      # and avoid using actionAlreadyProcessed
      if @mouseButton is "left"
        expectedClick = "mouseClickLeft"
      else
        expectedClick = "mouseClickRight"
        if @mouseButton
          if !alreadyRecordedLeftOrRightClickOnMenuItem
            # this being a right click, pop
            # up a menu as needed.
            if AutomatorRecorderAndPlayer?
              @world.automatorRecorderAndPlayer.addOpenContextMenuCommand morph.uniqueIDString()

      # trigger the action
      until morph[expectedClick]
        morph = morph.parent
        if not morph?
          break
      if morph?
        if morph == @mouseDownMorph

          switch expectedClick
            when "mouseClickLeft"
              pointerAndMorphInfo = world.getPointerAndMorphInfo()
              if AutomatorRecorderAndPlayer?
                world.automatorRecorderAndPlayer.addMouseClickCommand 0, nil, pointerAndMorphInfo...
              morph.mouseUpLeft? @position(), button, buttons, ctrlKey, shiftKey, altKey, metaKey
            when "mouseClickRight"
              pointerAndMorphInfo = world.getPointerAndMorphInfo()
              if AutomatorRecorderAndPlayer?
                world.automatorRecorderAndPlayer.addMouseClickCommand 2, nil, pointerAndMorphInfo...
              morph.mouseUpRight? @position(), button, buttons, ctrlKey, shiftKey, altKey, metaKey

          # also send doubleclick if the
          # two clicks happen on the same morph
          doubleClickInvocation = false

          if @doubleClickMorph?
            # three conditions:
            #  - both clicks are left-button clicks
            #  - both clicks on same widget
            #  - both clicks nearby
            if @mouseButton == "left" and
             @doubleClickMorph == morph and
             ((@doubleClickPosition.distanceTo @position()) < WorldMorph.preferencesAndSettings.grabDragThreshold)
              #console.log "@doubleClickPosition.distanceTo @position():" + @doubleClickPosition.distanceTo @position()
              #console.log "WorldMorph.preferencesAndSettings.grabDragThreshold:" + WorldMorph.preferencesAndSettings.grabDragThreshold
              @doubleClickMorph = nil
              disableConsecutiveClicksFromSingleClicksDueToFastTests = false
              if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
                if !window.world.automatorRecorderAndPlayer.runningInSlowMode()
                  disableConsecutiveClicksFromSingleClicksDueToFastTests = true
              if !disableConsecutiveClicksFromSingleClicksDueToFastTests
                # remember we are going to send a double click
                # but let's do it after. That's because we first
                # want to send the normal click AND we want to tell
                # in the normal click that that normal click is part
                # of a double click
                doubleClickInvocation = true
                # triple-click detection starts here, it's just
                # like chaining a second double-click detection
                # once this double-click has just been detected
                # right here.
                @rememberTripleClickMorphsForAWhile morph
            else
              @forgetDoubleClickMorphs()
          else
            @rememberDoubleClickMorphsForAWhile morph

          tripleClickInvocation = false

          # also send tripleclick if the
          # three clicks happen on the same morph
          # Don't do anything if a double-click has
          # just been invoked because you'd immediately
          # fire a tripleClick
          # This pargraph of code is basically the same
          # as the previous one.
          if !doubleClickInvocation
            # same three conditions as double click
            if @mouseButton == "left" and
             @tripleClickMorph == morph and
             ((@tripleClickPosition.distanceTo @position()) < WorldMorph.preferencesAndSettings.grabDragThreshold)
              #debugger
              if @tripleClickMorph == morph
                @tripleClickMorph = nil
                disableConsecutiveClicksFromSingleClicksDueToFastTests = false
                if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
                  if !window.world.automatorRecorderAndPlayer.runningInSlowMode()
                    disableConsecutiveClicksFromSingleClicksDueToFastTests = true
                if !disableConsecutiveClicksFromSingleClicksDueToFastTests
                  # remember we are going to send a triple click
                  # but let's do it after. That's because we first
                  # want to send the normal click AND we want to tell
                  # in the normal click that that normal click is part
                  # of a triple click
                  tripleClickInvocation = true
              else
                @forgetTripleClickMorphs()

          # fire the click, sending info on whether this was part
          # of a double/triple click
          if !morph.editorContentPropertyChangerButton and !(morph instanceof HorizontalMenuPanelWdgt)
            world.lastNonTextPropertyChangerButtonClickedOrDropped = morph
          morph[expectedClick] @position(), button, buttons, ctrlKey, shiftKey, altKey, metaKey, doubleClickInvocation, tripleClickInvocation
          #console.log ">>> sent event " + expectedClick + " to: " + morph

          # now send the double/triple clicks
          if doubleClickInvocation
            @processDoubleClick morph
          if tripleClickInvocation
            @processTripleClick morph


      # some pop-overs can contain horizontal sliders
      # and when the user interacts with them, it's easy
      # that she can "drag" them outside the range and
      # do the mouse-up outside the boundaries
      # of the pop-over. So we avoid that here, if there
      # is a non-float drag ongoing then we avoid
      # cleaning-up the pop-overs
      if !@nonFloatDraggedMorph?
        @cleanupMenuMorphs expectedClick, morph

    @mouseButton = nil
    @nonFloatDraggedMorph = nil


  forgetDoubleClickMorphs: ->
    @doubleClickMorph = nil
    @doubleClickPosition = nil

  rememberDoubleClickMorphsForAWhile: (morph) ->
    @doubleClickMorph = morph
    @doubleClickPosition = @position()
    setTimeout (=>
      #if @doubleClickMorph?
      #  console.log "single click"
      @forgetDoubleClickMorphs()
      return false
    ), 300

  # basically the same as rememberDoubleClickMorphsForAWhile
  forgetTripleClickMorphs: ->
    @tripleClickMorph = nil
    @tripleClickPosition = nil

  rememberTripleClickMorphsForAWhile: (morph) ->
    @tripleClickMorph = morph
    @tripleClickPosition = @position()
    setTimeout (=>
      #if @tripleClickMorph?
      #  console.log "not a triple click, just a double click"
      @forgetTripleClickMorphs()
      return false
    ), 300

  cleanupMenuMorphs: (expectedClick, morph, alsoKillFreshMenus)->

    world.hierarchyOfClickedMorphs = []
    world.hierarchyOfClickedMenus = []

    # note that all the actions due to the clicked
    # morphs have been performed, now we can destroy
    # morphs queued up for closure
    # which might include menus...
    # if we destroyed menus earlier, the
    # actions that come from the click
    # might be mangled, e.g. adding a menu
    # to a destroyed menu, etc.
    world.closePopUpsMarkedForClosure()

    # remove menus that have requested
    # to be removed when a click happens outside
    # of their bounds OR the bounds of their
    # children
    #if expectedClick == "mouseClickLeft"
    # collect all morphs up the hierarchy of
    # the one the user clicked on.
    # (including the one the user clicked on)
    ascendingMorphs = morph
    world.hierarchyOfClickedMorphs = [ascendingMorphs]
    while ascendingMorphs.parent?
      ascendingMorphs = ascendingMorphs.parent
      world.hierarchyOfClickedMorphs.push ascendingMorphs

    # remove menus that have requested
    # to be removed when a click happens outside
    # of their bounds OR the bounds of their
    # children
    #if expectedClick == "mouseClickLeft"
    # collect all the menus up the hierarchy of
    # the one the user clicked on.
    # (including the one the user clicked on)
    # note that the hierarchy of the menus is actually
    # via the getParentPopUp method
    firstParentThatIsAPopUp = morph.firstParentThatIsAPopUp()
    if firstParentThatIsAPopUp?.hierarchyOfPopUps?
      world.hierarchyOfClickedMenus = firstParentThatIsAPopUp.hierarchyOfPopUps()
    
    # go through the morphs that wanted a notification
    # in case there is a click outside of them or any
    # of their children.
    # i.e. check from the notification list which ones are not
    # in the hierarchy of the clicked morphs
    # and call their callback.
    #console.log "morphs wanting to be notified: " + world.morphsDetectingClickOutsideMeOrAnyOfMeChildren
    #console.log "hierarchy of clicked morphs: " + world.hierarchyOfClickedMorphs
    #console.log "hierarchy of clicked menus: " + world.hierarchyOfClickedMenus
    

    # here we do a shallow copy of world.morphsDetectingClickOutsideMeOrAnyOfMeChildren
    # because we might remove elements of the array while we
    # iterate on it (as we destroy menus that want to be destroyed
    # when the user clicks outside of them or their children)
    # so we need to do a shallow copy to avoid to mangle the for loop
    morphsDetectingClickOutsideMeOrAnyOfMeChildren = arrayShallowCopy world.morphsDetectingClickOutsideMeOrAnyOfMeChildren
    for eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren in morphsDetectingClickOutsideMeOrAnyOfMeChildren
      if (eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren not in world.hierarchyOfClickedMenus) and
         (eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren not in world.hierarchyOfClickedMorphs)
        # skip the freshly created menus as otherwise we might
        # destroy them immediately
        if alsoKillFreshMenus or eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren not in world.freshlyCreatedPopUps
          if eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren.clickOutsideMeOrAnyOfMeChildrenCallback[0]?
            eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren[eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren.clickOutsideMeOrAnyOfMeChildrenCallback[0]].call eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren, eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren.clickOutsideMeOrAnyOfMeChildrenCallback[1], eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren.clickOutsideMeOrAnyOfMeChildrenCallback[2], eachMorphWantingToBeNotifiedIfClickOutsideThemOrTheirChildren.clickOutsideMeOrAnyOfMeChildrenCallback[3]

  processDoubleClick: (morph = @topMorphUnderPointer()) ->
    pointerAndMorphInfo = world.getPointerAndMorphInfo morph
    if AutomatorRecorderAndPlayer?
      world.automatorRecorderAndPlayer.addMouseDoubleClickCommand nil, pointerAndMorphInfo...

    @destroyToolTips()
    if @floatDraggingSomething()
      @drop()
    else
      morph = morph.parent  while morph and not morph.mouseDoubleClick
      morph.mouseDoubleClick @position() if morph
    @mouseButton = nil

  processTripleClick: (morph = @topMorphUnderPointer()) ->
    pointerAndMorphInfo = world.getPointerAndMorphInfo morph
    if AutomatorRecorderAndPlayer?
      world.automatorRecorderAndPlayer.addMouseTripleClickCommand nil, pointerAndMorphInfo...

    @destroyToolTips()
    if @floatDraggingSomething()
      @drop()
    else
      morph = morph.parent  while morph and not morph.mouseTripleClick
      morph.mouseTripleClick @position() if morph
    @mouseButton = nil
  
  # see https://developer.mozilla.org/en-US/docs/Web/Events/wheel
  processWheel: (deltaX, deltaY, deltaZ, altKey, button, buttons) ->
    morph = @topMorphUnderPointer()
    morph = morph.parent  while morph and not morph.wheel

    if morph?
      morph.wheel deltaX, deltaY, deltaZ, altKey, button, buttons
  
  
  #
  # drop event:
  #
  #        droppedImage
  #        droppedSVG
  #        droppedAudio
  #        droppedText
  #
  processDrop: (event) ->
    #
    #    find out whether an external image or audio file was dropped
    #    onto the world canvas, turn it into an offscreen canvas or audio
    #    element and dispatch the
    #    
    #        droppedImage(canvas, name)
    #        droppedSVG(image, name)
    #        droppedAudio(audio, name)
    #    
    #    events to interested Widgets at the mouse pointer
    #    if none of the above content types can be determined, the file contents
    #    is dispatched as an ArrayBuffer to interested Widgets:
    #
    #    ```droppedBinary(anArrayBuffer, name)```

    files = (if event instanceof FileList then event else (event.target.files || event.dataTransfer.files))
    url = (if event.dataTransfer then event.dataTransfer.getData("URL") else nil)
    txt = (if event.dataTransfer then event.dataTransfer.getData("Text/HTML") else nil)
    targetDrop = @topMorphUnderPointer()
    img = new Image()

    readSVG = (aFile) ->
      pic = new Image()
      frd = new FileReader()
      target = target.parent  until target.droppedSVG
      pic.onload = ->
        target.droppedSVG pic, aFile.name
      frd = new FileReader()
      frd.onloadend = (e) ->
        pic.src = e.target.result
      frd.readAsDataURL aFile

    readImage = (aFile) ->
      pic = new Image()
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedImage
      pic.onload = ->
        canvas = newCanvas new Point pic.width, pic.height
        canvas.getContext("2d").drawImage pic, 0, 0
        targetDrop.droppedImage canvas, aFile.name

      frd = new FileReader()
      frd.onloadend = (e) ->
        pic.src = e.target.result

      frd.readAsDataURL aFile

    readAudio = (aFile) ->
      snd = new Audio()
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedAudio
      frd.onloadend = (e) ->
        snd.src = e.target.result
        targetDrop.droppedAudio snd, aFile.name
      frd.readAsDataURL aFile
    
    readText = (aFile) ->
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedText
      frd.onloadend = (e) ->
        targetDrop.droppedText e.target.result, aFile.name
      frd.readAsText aFile


    readBinary = (aFile) ->
      frd = new FileReader()
      targetDrop = targetDrop.parent  until targetDrop.droppedBinary
      frd.onloadend = (e) ->
        targetDrop.droppedBinary e.target.result, aFile.name
      frd.readAsArrayBuffer aFile

    parseImgURL = (html) ->
      url = ""
      start = html.indexOf "<img src=\""
      return nil  if start is -1
      start += 10
      for i in [start...html.length]
        c = html[i]
        return url  if c is "\""
        url = url.concat c
      nil
    
    if files.length
      for file in files
        if file.type.contains("svg") && !WorldMorph.preferencesAndSettings.rasterizeSVGs
          readSVG file
        else if file.type.indexOf("image") is 0
          readImage file
        else if file.type.indexOf("audio") is 0
          readAudio file
        else if file.type.indexOf("text") is 0
          readText file
        else
          readBinary file
    else if url
      if url.slice(url.lastIndexOf(".") + 1).toLowerCase() in ["gif", "png", "jpg", "jpeg", "bmp"]
        target = target.parent  until target.droppedImage
        img = new Image()
        img.onload = ->
          canvas = newCanvas new Point img.width, img.height
          canvas.getContext("2d").drawImage img, 0, 0
          target.droppedImage canvas
        img.src = url
    else if txt
      targetDrop = targetDrop.parent  until targetDrop.droppedImage
      img = new Image()
      img.onload = ->
        canvas = newCanvas new Point img.width, img.height
        canvas.getContext("2d").drawImage img, 0, 0
        targetDrop.droppedImage canvas
      src = parseImgURL txt
      img.src = src  if src
  
  
  # HandMorph tools
  destroyToolTips: ->

    # "toolTipsList" keeps a list of widgets which will be deleted upon
    # the next mouse click, or whenever another temporary Widget decides
    # that it needs to remove them.
    # Note that we actually destroy toolTipsList because we are not expecting
    # anybody to revive them once they are gone (as opposed to menus)

    # use a shallow copy of the list because we are
    # removing elements while iterating through it
    scanningTemporaries = arrayShallowCopy @toolTipsList
    scanningTemporaries.forEach (morph) =>
      unless morph.boundsContainPoint @position()
        morph.fullDestroy()
        @toolTipsList.remove morph
  
  
  # HandMorph floatDragging optimization
  fullRawMoveBy: (delta) ->
    if delta.isZero() then return
    trackChanges.push false
    #console.log "move 2"
    @breakNumberOfRawMovesAndResizesCaches()
    super delta
    trackChanges.pop()
    @fullChanged()

  processMouseMove: (worldX, worldY, button, buttons, ctrlKey, shiftKey, altKey, metaKey) ->
    #startProcessMouseMove = new Date().getTime()
    pos = new Point worldX, worldY
    @fullRawMoveTo pos

    if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
      mousePointerIndicator = document.getElementById "mousePointerIndicator"
      mousePointerIndicator.style.display = 'block'
      posInDocument = getDocumentPositionOf @world.worldCanvas
      mousePointerIndicator.style.left = (posInDocument.x + worldX - (mousePointerIndicator.clientWidth/2)) + 'px'
      mousePointerIndicator.style.top = (posInDocument.y + worldY - (mousePointerIndicator.clientHeight/2)) + 'px'

    # determine the new mouse-over-list.
    # Spacial multiplexing
    # (search "multiplexing" for the other parts of
    # code where this matters)
    # There are two interpretations of what this
    # list should be:
    #   1) all morphs "pierced through" by the pointer
    #   2) all morphs parents of the topmost morph under the pointer
    # 2 is what is used in Cuis
    
    # commented-out implementation of 1):
    # mouseOverNew = @allMorphsAtPointer().reverse()
    topMorph = @topMorphUnderPointer()
    mouseOverNew = topMorph.allParentsTopToBottom()

    @determineGrabs pos, topMorph, mouseOverNew

    @dispatchEventsFollowingMouseMove mouseOverNew

  checkDraggingTreshold: ->
    # UNFORTUNATELY OLD tests didn't take the correction into account,
    # pointers inevitably have some "noise", so to avoid that
    # a simple clicking (which could be done for example for
    # selection purposes or to pick a position for a cursor)
    # turns into a drag, so we add
    # a grab/drag distance threshold.
    # Note that even if the mouse moves a bit, we are still
    # picking up the correct morph that was under the mouse when
    # the mouse down happened.
    # Also we correct for the initial displacement
    # due to the threshold, so really when user starts dragging
    # it should pick up the EXACT point where the click happened,
    # not a "later" point once the threshold is passed.

    # so we have to bypass this mechanism for those.
    displacementDueToGrabDragThreshold = nil
    skipGrabDragThreshold = false
    
    if AutomatorRecorderAndPlayer? and AutomatorRecorderAndPlayer.state == AutomatorRecorderAndPlayer.PLAYING
      currentlyPlayingTestName = world.automatorRecorderAndPlayer.currentlyPlayingTestName
      if !window["#{currentlyPlayingTestName}"].grabDragThreshold?
        skipGrabDragThreshold = true

    if !skipGrabDragThreshold
      if @morphToGrab.parent != world or (!@morphToGrab.isEditable? or @morphToGrab.isEditable )
        if (@mouseDownPosition.distanceTo @position()) < WorldMorph.preferencesAndSettings.grabDragThreshold
          return [true,nil]
      displacementDueToGrabDragThreshold = @position().subtract @mouseDownPosition

    return [false, displacementDueToGrabDragThreshold]

  determineGrabs: (pos, topMorph, mouseOverNew) ->
    if !@draggingSomething() and (@mouseButton is "left")
      morph = topMorph.findRootForGrab()
      topMorph.mouseMove pos  if topMorph.mouseMove

      # if a morph is marked for grabbing, grab it
      if @morphToGrab
        
        # these first two cases are for float dragging
        # the third case is non-float drag
        if @morphToGrab.isTemplate
          [skipDragging, displacementDueToGrabDragThreshold] = @checkDraggingTreshold()
          if skipDragging then return

          morph = @morphToGrab.fullCopy()
          morph.isTemplate = false
          @grab morph, displacementDueToGrabDragThreshold
          @grabOrigin = @morphToGrab.situation()

        else if @morphToGrab.detachesWhenDragged()
          [skipDragging, displacementDueToGrabDragThreshold] = @checkDraggingTreshold()
          if skipDragging then return

          originalMorphToGrab = @morphToGrab
          @morphToGrab = @morphToGrab.grabbedWidgetSwitcheroo()
          morph = @morphToGrab
          @grab morph, displacementDueToGrabDragThreshold, (originalMorphToGrab != morph)

        else
          # non-float drags are for things such as sliders
          # and resize handles.
          # you could have the concept of de-noising, but
          # actually it seems nicer to have a "springy"
          # reaction to a slider with some noise.
          # Users don't seem to click on a slider for any other
          # reason than to move it (as opposed to selecting them
          # or picking a position for a cursor), so it's OK.
          @nonFloatDraggedMorph = @morphToGrab         
          @nonFloatDragPositionWithinMorphAtStart =
            # if we ever will need to compensate for the grab/drag
            # treshold here, just add .subtract displacementDueToGrabDragThreshold
            (pos.subtract @nonFloatDraggedMorph.position())


        # if the mouse has left its fullBounds, center it
        if morph
          fb = morph.fullBounds()
          unless fb.containsPoint pos
            @rawSetExtent @extent().subtract fb.extent().floorDivideBy 2
            @grab morph
            @fullRawMoveTo pos
    #endProcessMouseMove = new Date().getTime()
    #timeProcessMouseMove = endProcessMouseMove - startProcessMouseMove
    #console.log('Execution time ProcessMouseMove: ' + timeProcessMouseMove)


    if @nonFloatDraggingSomething()
      #console.log "nonFloatDraggedMorph: " + @nonFloatDraggedMorph

      # OK so this is an interesting choice. You can avoid
      # this next line and have ZK to behave like OSX where you
      # can scroll on a panel without bringing its window in the
      # foreground. OR you can have the window to automatically
      # pop into the foreground. I'm liking the OSX style
      # so I'm leaving this commented-out, but it's there.
      # TODO this could be a setting somewhere in ZK.
      # @nonFloatDraggedMorph.bringToForeground()

      if @mouseButton
        if @previousNonFloatDraggingPos?
          deltaDragFromPreviousCall = pos.subtract @previousNonFloatDraggingPos
        else
          deltaDragFromPreviousCall = nil
        @previousNonFloatDraggingPos = pos.copy()
        @nonFloatDraggedMorph.nonFloatDragging?(@nonFloatDragPositionWithinMorphAtStart, pos, deltaDragFromPreviousCall)
    

  # this is used by the ScrollMorph: clicking on the slider
  # (but OUTSIDE of the button), the (center of the) button
  # is immediately non-float dragged to where clicked.
  nonFloatDragMorphFarAwayToHere: (morphFarAway, pos) ->
    mouseOverNew = morphFarAway.allParentsTopToBottom()
    @previousNonFloatDraggingPos = morphFarAway.center()
    @nonFloatDragPositionWithinMorphAtStart = (new Point morphFarAway.width()/2, morphFarAway.height()/2).round()
    @nonFloatDraggedMorph = morphFarAway
    # this one calls the morphFarAway's nonFloatDragging method,
    # for example in case of a SliderMorph invoking this on its
    # button, this causes the movement of the button
    # and adjusting of the Slider values and potentially
    # adjusting scrollpanel etc.
    @determineGrabs pos, morphFarAway, mouseOverNew

  reCheckMouseEntersAndMouseLeavesAfterPotentialGeometryChanges: ->
    topMorph = @topMorphUnderPointer()
    mouseOverNew = topMorph.allParentsTopToBottom()
    @dispatchEventsFollowingMouseMove mouseOverNew

  dispatchEventsFollowingMouseMove: (mouseOverNew) ->

    @mouseOverList.forEach (old) =>
      unless old in mouseOverNew
        old.mouseLeave?()
        old.mouseLeavefloatDragging?()  if @mouseButton

    mouseOverNew.forEach (newMorph) =>
      
      # send mouseMove only if mouse actually moved,
      # otherwise it will fire also when the user
      # simply clicks
      if !@mouseDownPosition? or !@mouseDownPosition.eq @position()
        newMorph.mouseMove?(@position(), @mouseButton)
      
      unless newMorph in @mouseOverList
        newMorph.mouseEnter?()
        newMorph.mouseEnterfloatDragging?()  if @mouseButton

      # autoScrolling support:
      if @floatDraggingSomething()
        widgetBeingFloatDragged = @children[0]
        # if we are dragging stuff that can't be dropped
        # (e.g. external windows) then nothing happens
        if !widgetBeingFloatDragged.rejectsBeingDropped? or !widgetBeingFloatDragged.rejectsBeingDropped()
          if newMorph instanceof ScrollPanelWdgt
            if newMorph.wantsDropOf widgetBeingFloatDragged
              if !newMorph.boundingBox().insetBy(
                WorldMorph.preferencesAndSettings.scrollBarsThickness * 3
                ).containsPoint @position()
                  newMorph.startAutoScrolling()

    @mouseOverList = mouseOverNew
