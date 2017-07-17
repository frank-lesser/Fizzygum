# CloseIconButtonMorph //////////////////////////////////////////////////////

# sends a message to a target object when pressed.
# Takes the shape of an icon, and can also host
# a morph to be used as "face"
#
# You could achieve something similar by having
# an empty button containing an icon, but changing
# the color of a face belonging to a button is
# not yet supported.
# i.e. this is currently the simplest way to change the color
# of a non-ractangular button.

class CloseIconButtonMorph extends EmptyButtonMorph
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype


  defaultCloseIconAppearance: """
    fillColor = @morph.color

    # The circle
    context.beginPath()
    context.moveTo 100.5, 196.5
    context.bezierCurveTo 153.91, 196.5, 197.5, 152.91, 197.5, 99.5
    context.bezierCurveTo 197.5, 46.09, 153.91, 2.5, 100.5, 2.5
    context.bezierCurveTo 47.09, 2.5, 3.5, 46.09, 3.5, 99.5
    context.bezierCurveTo 3.5, 152.91, 47.09, 196.5, 100.5, 196.5
    context.closePath()
    context.moveTo 100.5, 15.1
    context.bezierCurveTo 147.11, 15.1, 184.9, 52.89, 184.9, 99.5
    context.bezierCurveTo 184.9, 146.11, 147.11, 183.9, 100.5, 183.9
    context.bezierCurveTo 53.89, 183.9, 16.1, 146.11, 16.1, 99.5
    context.bezierCurveTo 16.1, 52.89, 53.89, 15.1, 100.5, 15.1
    context.closePath()
    context.fillStyle = fillColor
    context.fill()

    # The x inside the circle
    context.beginPath()
    context.moveTo 65.73, 134.27
    context.bezierCurveTo 66.99, 135.53, 68.5, 136.03, 70.27, 136.03
    context.bezierCurveTo 72.03, 136.03, 73.54, 135.53, 74.8, 134.27
    context.lineTo 100.5, 108.32
    context.lineTo 126.45, 134.27
    context.bezierCurveTo 127.71, 135.53, 129.22, 136.03, 130.99, 136.03
    context.bezierCurveTo 132.75, 136.03, 134.26, 135.53, 135.52, 134.27
    context.bezierCurveTo 138.04, 131.75, 138.04, 127.72, 135.52, 125.45
    context.lineTo 109.32, 99.5
    context.lineTo 135.27, 73.55
    context.bezierCurveTo 137.79, 71.03, 137.79, 67, 135.27, 64.73
    context.bezierCurveTo 132.75, 62.21, 128.72, 62.21, 126.45, 64.73
    context.lineTo 100.5, 90.68
    context.lineTo 74.55, 64.73
    context.bezierCurveTo 72.03, 62.21, 68, 62.21, 65.73, 64.73
    context.bezierCurveTo 63.21, 67.25, 63.21, 71.28, 65.73, 73.55
    context.lineTo 91.68, 99.5
    context.lineTo 65.73, 125.45
    context.bezierCurveTo 63.21, 127.72, 63.21, 131.75, 65.73, 134.27
    context.closePath()
    context.fillStyle = fillColor
    context.fill()

    """


  constructor: (@target) ->
    # can't set the parent as the target directly because this morph
    # might not have a parent yet.
    super true, @, 'actOnClick', new Morph()
    @color_hover = new Color 255,0,0
    @color_pressed = @color_hover
    @appearance = new IconAppearance @, @defaultCloseIconAppearance


  actOnClick: ->
    @parent?.fullDestroy()

  # otherwise the close button on windows causes
  # a floatdrag most of the times instead of closing
  # the window, because of the pointer noise.
  isFloatDraggable: ->
    false
  rootForGrab: ->
    return null
