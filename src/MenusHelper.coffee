# MenusHelper ////////////////////////////////////////////////////////////

# All "actions" functions for all accessory menu items should belong
# in here. Also helps so we don't pollute moprhs with a varying number
# of helper functions, which is problematic for visual diffing
# on inspectors (the number of methods keeps changing).

class MenusHelper
  # this is so we can create objects from the object class name 
  # (for the deserialization process)
  namedClasses[@name] = @prototype

  @augmentWith DeepCopierMixin

  createFridgeMagnets: ->
    world.create new FridgeMagnetsMorph()

  createReconfigurablePaint: ->
    world.create new ReconfigurablePaintMorph()

  createSimpleButton: ->
    world.create new SimpleButtonMorph true, @, null, new IconMorph(new Point(200,200),null)

  createSwitchButtonMorph: ->
    button1 = new SimpleButtonMorph true, @, null, new IconMorph(new Point(200,200),null)
    button2 = new SimpleButtonMorph true, @, null, new StringMorph2 "Hello World! ⎲ƒ⎳⎷ ⎸⎹ "
    world.create new SwitchButtonMorph [button1, button2]

