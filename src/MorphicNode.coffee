class MorphicNode

  parent: null
  # "children" is an ordered list of the immediate
  # children of this node. First child is at the
  # back relative to other children, last child is at the
  # top.
  # This makes intuitive sense if you think for example
  # at a textMorph being added to a box morph: it is
  # added to the children list of the box morph, at the end,
  # and it's painted on top (otherwise it wouldn't be visible).
  # Note that when you add a morph A to a morph B, it doesn't
  # mean that A is cointained in B. The two potentially might
  # not even overlap.
  # The shadow is added as the first child, and it's
  # actually a special child that gets drawn before the
  # others.
  children: null

  constructor: (@parent = null, @children = []) ->
  
  
  # MorphicNode string representation: e.g. 'a MorphicNode[3]'
  toString: ->
    "a MorphicNode" + "[" + @children.length + "]"

  # currently unused in ZK
  childrenTopToBottom: ->
    arrayShallowCopyAndReverse(@children)  
  
  # MorphicNode accessing:
  addChild: (aMorphicNode) ->
    @children.push aMorphicNode
    aMorphicNode.parent = @
  
  addChildFirst: (aMorphicNode) ->
    @children.splice 0, null, aMorphicNode
    aMorphicNode.parent = @
  
  removeChild: (aMorphicNode) ->
    idx = @children.indexOf(aMorphicNode)
    @children.splice idx, 1  if idx isnt -1
  
  
  # MorphicNode functions:
  root: ->
    return @parent.root() if @parent?
    @
  
  # currently unused
  depth: ->
    return 0  unless @parent
    @parent.depth() + 1
  
  # Returns all the internal AND terminal nodes in the subtree starting
  # at this node - including this node.
  # Remember that the @children property already sorts morphs
  # from bottom to top

  allChildrenBottomToTop: ->
    result = [@] # includes myself
    @children.forEach (child) ->
      result = result.concat(child.allChildrenBottomToTop())
    result

  # the easiest way here would be to just return
  #   arrayShallowCopyAndReverse(@allChildrenBottomToTop())
  # but that's slower.
  # So we do the proper visit here instead.
  allChildrenTopToBottom: ->
    # base case - I am a leaf child, so I just
    # return an array with myself
    # note that I return an array rather than the
    # element cause this method is always expected
    # to return an array.
    if @children.length == 0
      return [@]

    # if I have some children instead, then let's create
    # an empty array where we'll concatenate the
    # others.
    arrayToReturn = []

    # if I have children, then start from the top
    # one (i.e. the last in the array) towards the bottom
    # one and concatenate their respective
    # top-to-bottom lists
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      arrayToReturn = arrayToReturn.concat morph.allChildrenTopToBottom

    # ok, last we add ourselves to the bottom
    # of the list since this node is at the bottom of all of
    # its children...
    arrayToReturn.push @


  # A shorthand to run a function on all the internal/terminal nodes in the subtree
  # starting at this node - including this node.
  # Note that the function first runs on this node (which is the bottom-est morph)
  # and the proceeds by visiting the "bottom" child (first one in array)
  # and then all its children and then the second - bottomest child etc.
  # Also note that there is a more elegant implementation where
  # we just use @allChildrenBottomToTop() but that would mean to create
  # all the intermediary arrays with also all the unneeded node elements,
  # there is not need.
  forAllChildrenBottomToTop: (aFunction) ->
    aFunction.call null, @
    if @children.length
      @children.forEach (child) ->
        child.forAllChildrenBottomToTop aFunction
  
  # not used in ZK so far
  allLeafsBottomToTop: ->
    if @children.length == 0
      return [@]
    @children.forEach (child) ->
      result = result.concat(child.allLeafsBottomToTop())
    return result

  # Return all "parent" nodes from the root up to this node (including both)
  allParentsBottomToTop: ->
    if @parent?
      someParents = @parent.allParentsBottomToTop()
      someParents.push @
      return someParents
    else
      return [@]
  
  # Return all "parent" nodes from this node up to the root (including both)
  # Implementation commented-out below works but it's probably
  # slower than the one given, because concat is slower than pushing just
  # an array element, since concat does a shallow copy of both parts of
  # the array...
  #   allParentsTopToBottom: ->
  #    # includes myself
  #    result = [@]
  #    if @parent?
  #      result = result.concat(@parent.allParentsTopToBottom())
  #    result

  allParentsTopToBottom: ->
    return @allParentsBottomToTop().reverse()

  # this should be quicker than allParentsTopToBottomSuchThat
  # cause there are no concats making shallow copies.
  allParentsBottomToTopSuchThat: (predicate) ->
    result = []
    if @parent?
      result = @parent.allParentsBottomToTopSuchThat(predicate)
    if predicate.call(null, @)
      result.push @
    result

  allParentsTopToBottomSuchThat: (predicate) ->
    collected = []
    if predicate.call(null, @)
      collected = [@] # include myself
    if @parent?
      collected = collected.concat(@parent.allParentsTopToBottomSuchThat(predicate))
    return collected

  # quicker version that doesn't need us
  # to create any intermediate arrays
  # but rather just loops up the chain
  # and lets us return as soon as
  # we find a match
  containedInParentsOf: (morph) ->
    # test the morph itself
    if morph is @
      return true
    examinedMorph = morph
    while examinedMorph.parent?
      examinedMorph = examinedMorph.parent
      if examinedMorph is @
        return true
    return false

  # The direct children of the parent of this node. (current node not included)
  # never used in ZK
  # There is an alternative solution here below, in comment,
  # but I believe to be slower because it requires applying a function to
  # all the children. My version below just required an array copy, then
  # finding an element and splicing it out. I didn't test it so I don't
  # even know whether it works, but gut feeling...
  #  siblings: ->
  #    return []  unless @parent
  #    @parent.children.filter (child) =>
  #      child isnt @
  siblings: ->
    return []  unless @parent
    siblings = arrayShallowCopy @parent.children
    # now remove myself
    index = siblings.indexOf(@)
    siblings.splice(index, 1)
    return siblings

  # find how many siblings before me
  # satisfy a property
  # This is used when figuring out
  # how many buttons before a particular button
  # are labeled in the same way,
  # in the test system.
  # (so that we can say: automatically
  # click on the nth button labelled "X")
  howManySiblingsBeforeMeSuchThat: (predicate) ->
    theCount = 0
    for eachSibling in @parent.children
      if eachSibling == @
        return theCount
      if predicate.call(null, eachSibling)
        theCount++
    return theCount

  # find the nth child satisfying
  # a property.
  # This is used when finding
  # the nth buttons of a menu
  # having a particular label.
  # (so that we can say: automatically
  # click on the nth button labelled "X")
  nthChildSuchThat: (n, predicate) ->
    theCount = 0
    for eachChild in @children
      if predicate.call(null, eachChild)
        theCount++
        if theCount is n
          return eachChild
    return null
  
  # returns the first parent (going up from this node) that is of a particular class
  # (includes this particular node)
  # This is a subcase of "parentThatIsAnyOf".
  parentThatIsA: (constructor) ->
    # including myself
    return @ if @ instanceof constructor
    return null  unless @parent
    @parent.parentThatIsA constructor
  
  # returns the first parent (going up from this node) that belongs to a set
  # of classes. (includes this particular node).
  parentThatIsAnyOf: (constructors) ->
    # including myself
    constructors.forEach (each) =>
      if @constructor is each
        return @
    #
    return null  unless @parent
    @parent.parentThatIsAnyOf constructors

  # There is a simpler implementation that is also
  # slower where you first collect all the children
  # from top to bottom and then do the test on each
  # But this more efficient - we don't need to
  # create that entire list to start with, we just
  # navigate through the children arrays.
  topMorphSuchThat: (predicate) ->
    # base case - I am a leaf child, so I just test
    # the predicate on myself and return myself
    # if I satisfy, else I return null
    if @children.length == 0
      if predicate.call(null, @)
        return @
      else
        return null
    # if I have children, then start to test from
    # the top one (the last one in the array)
    # and proceed to test "towards the back" i.e.
    # testing elements of the array towards 0
    # If you find any morph satifies, the search is
    # over.
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      foundMorph = morph.topMorphSuchThat(predicate)
      if foundMorph?
        return foundMorph
    # now that all children are tested, test myself
    if predicate.call(null, @)
      return @
    else
      return null
    # ok none of my children nor me test positive,
    # so return null.
    return null

  topmostChildSuchThat: (predicate) ->
    # start to test from
    # the top one (the last one in the array)
    # and proceed to test "towards the back" i.e.
    # testing elements of the array towards 0
    # If you find any child that satifies, the search is
    # over.
    for morphNumber in [@children.length-1..0] by -1
      morph = @children[morphNumber]
      if predicate.call(null, morph)
        return morph
    # ok none of my children test positive,
    # so return null.
    return null

  collectAllChildrenBottomToTopSuchThat: (predicate) ->
    collected = []
    if predicate.call(null, @)
      collected = [@] # include myself
    @children.forEach (child) ->
      collected = collected.concat(child.collectAllChildrenBottomToTopSuchThat(predicate))
    return collected
