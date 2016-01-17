# ShadowMorph /////////////////////////////////////////////////////////
# REQUIRES BackBufferMixin

class ShadowMorph extends Morph
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype
  @augmentWith BackBufferMixin

  targetMorph: null
  offset: null
  alpha: 0
  color: null

  # alpha should be between zero (transparent)
  # and one (fully opaque)
  constructor: (@targetMorph, @offset = new Point(7, 7), @alpha = 0.2, @color = new Color(0, 0, 0)) ->
    # console.log "creating shadow morph"
    super()
    @bounds.debugIfFloats()
    @offset.debugIfFloats()

  reLayout: ->
    # console.log "shadow morph update rendering"
    super()
    fb = @targetMorph.fullBoundsNoShadow()
    @silentRawSetExtent fb.extent().add @targetMorph.shadowBlur * 2
    if WorldMorph.preferencesAndSettings.useBlurredShadows and !WorldMorph.preferencesAndSettings.isFlat
      @silentFullRawMoveTo fb.origin.add(@offset).subtract @targetMorph.shadowBlur
    else
      @silentFullRawMoveTo fb.origin.add @offset
    @bounds.debugIfFloats()
    @offset.debugIfFloats()
    @notifyChildrenThatParentHasReLayouted()

  createRefreshOrGetImmutableBackBuffer: ->

    cacheKey =
      @extent().toString() + "-" +
      @targetMorph.toStringWithoutGeometry()

    cacheHit = world.cacheForImmutableBackBuffers.get cacheKey
    if cacheHit? then return cacheHit

    @bounds.debugIfFloats()
    if WorldMorph.preferencesAndSettings.useBlurredShadows and !WorldMorph.preferencesAndSettings.isFlat
      backBuffer = @targetMorph.shadowImage @offset, @color, true
    else
      backBuffer = @targetMorph.shadowImage @offset, @color, false
    backBufferContext =  backBuffer.getContext "2d"
    @bounds.debugIfFloats()
    @offset.debugIfFloats()

    cacheEntry = [backBuffer, backBufferContext]
    world.cacheForImmutableBackBuffers.set cacheKey, cacheEntry
    return cacheEntry
