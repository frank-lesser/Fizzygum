# StringFieldMorph ////////////////////////////////////////////////////

class StringFieldMorph extends FrameMorph
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype

  defaultContents: null
  minWidth: null
  fontSize: null
  fontStyle: null
  isBold: null
  isItalic: null
  isNumeric: null
  text: null
  isEditable: true

  constructor: (
      @defaultContents = "",
      @minWidth = 100,
      @fontSize = 12,
      @fontStyle = "sans-serif",
      @isBold = false,
      @isItalic = false,
      @isNumeric = false
      ) ->
    super()
    @color = new Color(255, 255, 255)

  setWidth: (newWidth)->
    super(newWidth)
    @text.setWidth(newWidth)


  calculateAndUpdateExtent: ->
    txt = (if @text then @getValue() else @defaultContents)
    text = new StringMorph(txt, @fontSize, @fontStyle, @isBold, @isItalic, @isNumeric)
    console.log "text morph extent: " + text.text + " : " + text.extent()
    @setWidth(Math.max(@minWidth,text.width()))
    console.log "string fleid morph extent: " + @extent()

  reLayout: ->
    super()
    txt = (if @text then @getValue() else @defaultContents)
    @text = null
    @destroyAll()
    @text = new StringMorph(txt, @fontSize, @fontStyle, @isBold, @isItalic, @isNumeric)
    @text.isNumeric = @isNumeric # for whichever reason...
    @text.setPosition @bounds.origin.copy()
    @text.isEditable = @isEditable
    @text.isfloatDraggable = false
    @text.enableSelecting()    
    @silentSetExtent new Point(Math.max(@width(), @minWidth), @text.height())
    @add @text

  
  getValue: ->
    @text.text
  
  mouseClickLeft: (pos)->
    super()
    if @isEditable
      @text.edit()
    else
      @escalateEvent 'mouseClickLeft', pos
  
  