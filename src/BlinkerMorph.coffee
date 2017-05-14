# BlinkerMorph ////////////////////////////////////////////////////////

# can be used for text caret

class BlinkerMorph extends Morph
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype

  constructor: (@fps = 2) ->
    world.addSteppingMorph @
    super()
    @appearance = new RectangularAppearance @
    @color = new Color 0, 0, 0
  
  # BlinkerMorph stepping:
  step: ->
    # if we are recording or playing a test
    # then there is a flag we need to check that allows
    # the world to control all the animations.
    # This is so there is a consistent check
    # when taking/comparing
    # screenshots.
    # So we check here that flag, and make the
    # caret is always going to be visible.
    if AutomatorRecorderAndPlayer.animationsPacingControl and
     AutomatorRecorderAndPlayer.state != AutomatorRecorderAndPlayer.IDLE
      return
 
    # in all other cases just
    # do like usual, i.e. toggle
    # visibility at the fps
    # specified in the constructor.
    @toggleVisibility()
