class CollapsedStateIconAppearance extends IconAppearance

  constructor: (@morph) ->
    super
    @preferredSize = new Point 100, 100
    @specificationSize = new Point 400, 400

  paintFunction: (context) ->
    #// Color Declarations
    colorString = 'rgb(0, 0, 0)'
    #// Bezier Drawing
    context.beginPath()
    context.moveTo 44.5, 262.42
    context.lineTo 204.07, 111.5
    context.lineTo 360.5, 265.5
    context.strokeStyle = colorString
    context.lineWidth = 30
    context.stroke()
