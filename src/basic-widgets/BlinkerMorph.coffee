# can be used for text caret

class BlinkerMorph extends Widget

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
    if AutomatorRecorderAndPlayer? and
     AutomatorRecorderAndPlayer.animationsPacingControl and
     AutomatorRecorderAndPlayer.state != AutomatorRecorderAndPlayer.IDLE
      return
 
    # in all other cases just
    # do like usual, i.e. toggle
    # visibility at the fps
    # specified in the constructor.
    @toggleVisibility()
