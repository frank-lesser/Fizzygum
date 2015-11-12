# //////////////////////////////////////////////////////////

# these comments below needed to figure out dependencies between classes
# REQUIRES globalFunctions

# A BackingStore is a canvas that a morph can keep for
# two reasons:
#   1) as a cache
#   2) because the morph has inherently a "raster" nature
#      such as the canvas where you can run a turtle to
#      draw stuff, or a Morph where you want to have
#      pixel-based filters.
#
# The cache use is useful for morphs that ideally
#  * have a small extent
#  * have an expensive painting process
#  * are repainted often
#
# (Note that the cache for the time being is only
# for the very morph, not for the whole of the
# hierarchy.)
#
# Ideal use of a cache is tex,t because painting text
# can be a lengthy operation.
# Worst possible use of a cache is the large
# desktop background rectangle, where a lot of memory
# would be wasted for saving a very short painting
# operation.
#
# In theory the backing store use should be transparent and
# automatic, driven perhaps by dynamic considerations,
# but we are not there yet.

BackingStoreMixin =
  # klass properties here:
  # none

  # instance properties to follow:
  onceAddedClassProperties: ->
    @addInstanceProperties
      silentUpdateBackingStore: ->
        # initialize my surface property
        @image = newCanvas(@extent().scaleBy pixelRatio)
        context = @image.getContext("2d")
        context.scale pixelRatio, pixelRatio
        context.fillStyle = @color.toString()
        context.fillRect 0, 0, @width(), @height()
        if @cachedTexture
          @drawCachedTexture()
        else @drawTexture @texture  if @texture

      # This method only paints this very morph's "image",
      # it doesn't descend the children
      # recursively. The recursion mechanism is done by recursivelyBlit, which
      # eventually invokes blit.
      # Note that this morph might paint something on the screen even if
      # it's not a "leaf".
      blit: (aCanvas, clippingRectangle) ->
        return null  if @isMinimised or !@isVisible or !@image?
        area = clippingRectangle.intersect(@bounds).round()
        # test whether anything that we are going to be drawing
        # is visible (i.e. within the clippingRectangle)
        if area.isNotEmpty()
          delta = @position().neg()
          src = area.copy().translateBy(delta).round()
          context = aCanvas.getContext("2d")
          context.globalAlpha = @alpha
          sl = src.left() * pixelRatio
          st = src.top() * pixelRatio
          al = area.left() * pixelRatio
          at = area.top() * pixelRatio
          w = Math.min(src.width() * pixelRatio, @image.width - sl)
          h = Math.min(src.height() * pixelRatio, @image.height - st)
          return null  if w < 1 or h < 1

          context.drawImage @image,
            Math.round(sl),
            Math.round(st),
            Math.round(w),
            Math.round(h),
            Math.round(al),
            Math.round(at),
            Math.round(w),
            Math.round(h)

          if world.showRedraws
            randomR = Math.round(Math.random()*255)
            randomG = Math.round(Math.random()*255)
            randomB = Math.round(Math.random()*255)
            context.globalAlpha = 0.5
            context.fillStyle = "rgb("+randomR+","+randomG+","+randomB+")";
            context.fillRect(Math.round(al),Math.round(at),Math.round(w),Math.round(h));
