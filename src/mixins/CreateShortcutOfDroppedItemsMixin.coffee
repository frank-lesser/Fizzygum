# REQUIRES globalFunctions


CreateShortcutOfDroppedItemsMixin =
  # class properties here:
  # none

  # instance properties to follow:
  onceAddedClassProperties: (fromClass) ->
    @addInstanceProperties fromClass,

      # this is used in folder panels. Widgets that are
      # NOT shortcuts (object shortcuts or folders) that are
      # dropped are then going to be closed and their references
      # are going to be left in the folder instead.
      # HOWEVER we have to move that first "transient" widget dropped so that
      # it doesn't go "left" or "above" the folder panel, otherwise the
      # folder panel is going to resize so to fit the dropped widget
      # and the folder window is going to get scrollbars and the
      # subsequent shortcut is going to end up in a bad place instead
      # of the neat automatic grid positioning.
      # So, move the "transient" dropped widget just a bit to the
      # right and below the origin.
      aboutToDrop: (morphToDrop) ->
        if morphToDrop instanceof IconicDesktopSystemShortcutWdgt
          morphToDrop.fullRawMoveWithin @
        else
          morphToDrop.fullRawMoveTo @position().add new Point 10, 10

      reactToDropOf: (droppedWidget) ->
        super
        if !(droppedWidget instanceof IconicDesktopSystemShortcutWdgt)
          droppedWidget.createReferenceAndClose nil, @
