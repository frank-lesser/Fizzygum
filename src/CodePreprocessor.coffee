##
## CodePreprocessor takes care of translating the simplified syntax
## of livecodelb to a coffeescript that is degestible by the
## coffeescript compiler.
## This pre-processing step can raise some errors - which are
## returned in a dedicated variable.
##
## In order to run the tests from fizzygum:
##   world.children[5].children[2].lclCodeCompiler.codePreprocessor.test()
## or, to run a subset (useful for bisection in case something goes wrong):
##   ...test(rangeMin, rangeMax)
##

detailedDebug = false


# we want to have the following snippet to work:
#   flickering = <if random > 0.5 then scale 0>
#   flickering
#     box
#     peg
# in order to do that, we need to have "scale 0" inside
# that if to take a function (the box/peg block)
# in order to do that, we transform the if into
#    flickering = ifFunctional(random() > 0.5, scale function taking the block as argument)
# so flickering is a function that can take the block as argument.
ifFunctional = (condition, thenCode, elseCode) ->
  #console.log "outside: " + thenCode
  (afterBlocks...) ->
    #console.log "inside: " + thenCode
    #console.log "afterBlocks: " + afterBlocks
    #console.log "condition: " + condition
    if condition
      thenCode.apply this, afterBlocks
    else
      if elseCode?
        elseCode.apply this, afterBlocks
      else
        # in the example above, flickering might be
        # called without an argument and without
        # a block, so check that case
        if afterBlocks[0]?
          afterBlocks[0]()

window.ifFunctional = ifFunctional if window?

class CodePreprocessor

  testCases: [
     notes:    """
               An organic example which also
               tests whether multiple lines
               mangle things.
               """
     input:    """
               5 times
               ▶rotate 0,1,time/5000
               ▶move 0.2,0,0
               ▶3 times
               ▶▶rotate 1
               ▶▶box
               """
     expected: """
               5.times @, ->
               ▶rotate 0,1,time/5000
               ▶move 0.2,0,0
               ▶3.times @, ->
               ▶▶rotate 1
               ▶▶box()
               """
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               peg
               times
               ▶box 2
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               times
               ▶box
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               peg times rotate box 2* wave
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               if true then  times do that
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               if random() > 0.5 then rotate box else times rotate peg true
               """
     error: "how many times?"
    ,
     notes:    """
               Checking that times finds its "number of loops"
               expression correctly.
               """
     input:    """
               a = 2
               box a + 3 times rotate peg
               """
     expected: """
               a = 2
               box -> (a + 3).times @, -> rotate peg
               """
    ,
     notes:    """
               Checking "qualifying" rotate
               """
     input:    """
               6 times: rotate box
               """
     expected: """
               6.times @, -> rotate box
               """
    ,
     notes:    """
               Checking "qualifying" rotate and times within
               a function definition
               """
     input:    """
               myFunc = -> 20 times rotate box
               """
     expected: """
               myFunc = -> 20.times @, -> rotate box
               """
    ,
     notes:    """
               Checking "qualifying" rotate and times within
               if within a function definition with arguments
               """
     input:    """
               myFunc = (a,b) -> if true then 20 times rotate box
               """
     expected: """
               myFunc = (a,b) -> if true then 20.times @, -> rotate box
               """
    ,
     notes:    """
               Checking multiple times within if then statement
               """
     input:    """
               if true then 2 times box 3 times line 2
               """
     expected: """
               if true then 2.times @, -> box -> 3.times @, -> line 2
               """
    ,
     notes:    """
               Checking that separate rotate and primitive
               within a times body remain correctly separated.
               """
     input:    """
               6 times: rotate box
               """
     expected: """
               6.times @, -> rotate box
               """
    ,
     notes:    """
               Qualifying rotate within an indented "times" body
               """
     input:    """
               6 times:
               ▶rotate box
               """
     expected: """
               6.times @, ->
               ▶rotate box
               """
    ,
     input:    """
               1+1 times: rotate box
               """
     expected: """
               (1+1).times @, -> rotate box
               """
    ,
     input:    """
               peg 2 times rotate box 2* wave
               """
     expected: """
               peg -> 2.times @, -> rotate -> box 2* wave()
               """
    ,
     input:    """
               n = 2 n times: rotate box
               """
     expected: """
               n = 2; n.times @, -> rotate box
               """
    ,
     input:    """
               n = 2 (n+0).times rotate box()
               """
     expected: """
               n = 2; (n+0).times @, -> rotate box
               """
    ,
     input:    """
               n = 2 rotate(n+0) rotate() box()
               """
     expected: """
               n = 2; rotate(n+0); rotate(); box()
               """
    ,
     input:    """
               n = 2 rotate n + 1 box
               """
     expected: """
               n = 2; rotate n + 1, box
               """
    ,
     input:    """
               box box   2 times: rotate peg 1.3
               """
     expected: """
               box -> box -> 2.times @, -> rotate -> peg 1.3
               """
    ,
     input:    """
               if random > 0.5 then 3 times: rotate box else 3 times rotate 2 times: peg 1
               """
     expected: """
               if random() > 0.5 then 3.times @, -> rotate box else 3.times @, -> rotate -> 2.times @, -> peg 1
               """
    ,
     input:    """
               if true then 3 times rotate box
               """
     expected: """
               if true then 3.times @, -> rotate box
               """
    ,
     input:    """
               (9+0).times -> rotate box
               """
     expected: """
               (9+0).times @, -> rotate box
               """
    ,
     input:    """
               if random() > 0.5 then rotate box else 3 times rotate peg 1
               """
     expected: """
               if random() > 0.5 then rotate box else 3.times @, -> rotate -> peg 1
               """
    ,
     input:    """
               if random() > 0.5 then rotate 1 + wave box else 3 times rotate peg 1
               """
     expected: """
               if random() > 0.5 then rotate 1 + wave(), box else 3.times @, -> rotate -> peg 1
               """
    ,
     input:    """
               // testing whether mangled accross multiple lines
               if random() > 0.5 then box
               2 times: box
               2 times: rotate box
               """
     expected: """
               
               if random() > 0.5 then box()
               2.times @, box
               2.times @, -> rotate box
               """
    ,
     input:    """
               // testing whether mangled accross multiple lines
               6 times: rotate box
               6 times:
               ▶rotate box
               """
     expected: """

               6.times @, -> rotate box
               6.times @, ->
               ▶rotate box
               """
    ,
     input:    """
               ab
               """
     expected: """
               ab
               """
    ,
     input:    """
               ball line peg
               """
     expected: """
               ball -> line peg
               """
    ,
     input:    """
               box
               """
     expected: """
               box()
               """
    ,
     input:    """
               2 times rotate box wave wave
               """
     expected: """
               2.times @, -> rotate -> box wave wave()
               """
    ,
     notes:    """
               we should give an error in these cases
               """
     input:    """
               box + box
               """
     expected: """
               box +, box
               """
    ,
     input:    """
               wave wave wave
               """
     expected: """
               wave wave wave()
               """
    ,
     input:    """
               if wave then box wave else wave
               """
     expected: """
               if wave() then box wave() else wave()
               """
    ,
     input:    """
               if wave then box + wave else wave
               """
     expected: """
               if wave() then box + wave() else wave()
               """
    ,
     input:    """
               wave
               """
     expected: """
               wave()
               """
    ,
     # this is technically wrong,
     # but in fact will work, because
     # wave + wave is not assigned
     # or used for anything.
     # The transformation is only done when
     # the expression is preceded by an
     # operator, and in this case there is
     # nothing using the expression, so
     # this pre-processing is as good as
     # the technically correct one.
     input:    """
               wave + wave
               """
     expected: """
               wave + wave()
               """
    ,
     input:    """
               a = wave + wave
               """
     expected: """
               a = wave() + wave()
               """
    ,
     input:    """
               (wave + wave)
               """
     expected: """
               (wave() + wave())
               """
    ,
     input:    """
               wave
               """
     expected: """
               wave()
               """
    ,
     input:    """
               if random() > 0.5 then box
               """
     expected: """
               if random() > 0.5 then box()
               """
    ,
     input:    """
               2 times: box
               """
     expected: """
               2.times @, box
               """
    ,
     input:    """
               2 times: rotate box
               """
     expected: """
               2.times @, -> rotate box
               """
    ,
     input:    """
               2 times rotate box wave
               """
     expected: """
               2.times @, -> rotate -> box wave()
               """
    ,
     input:    """
               rotate box 2,33
               """
     expected: """
               rotate -> box 2,33
               """
    ,
     input:    """
               box wave
               """
     expected: """
               box wave()
               """
    ,
     input:    """
               box wave 3
               """
     expected: """
               box wave 3
               """
    ,
     input:    """
               2 times: rotate box wave
               """
     expected: """
               2.times @, -> rotate -> box wave()
               """
    ,
     input:    """
               if rotate wave then rotate wave else rotate wave
               """
     expected: """
               if rotate wave() then rotate wave() else rotate wave()
               """
    ,
     input:    """
               2 times: move rotate wave box
               """
     expected: """
               2.times @, -> move -> rotate wave(), box
               """
    ,
     input:    """
               rotate wave box
               """
     expected: """
               rotate wave(), box
               """
    ,
     input:    """
               box -1
               """
     expected: """
               box -1
               """
    ,
     input:    """
               box - 1
               """
     expected: """
               box - 1
               """
    ,
     input:    """
               a = box -1
               """
     expected: """
               a = box -1
               """
    ,
     input:    """
               a = box - 1
               """
     expected: """
               a = box - 1
               """
    ,
     input:    """
               wave -1
               """
     expected: """
               wave -1
               """
    ,
     # this is technically wrong,
     # but in fact will work, because
     # wave - 1 is not assigned
     # or used for anything.
     # The transformation is only done when
     # the expression is preceded by an
     # operator, and in this case there is
     # nothing using the expression, so
     # this pre-processing is as good as
     # the technically correct one.
     input:    """
               wave - 1
               """
     expected: """
               wave - 1
               """
    ,
     input:    """
               a = wave - 1
               """
     expected: """
               a = wave() - 1
               """
    ,
     input:    """
               box wave + 1
               """
     expected: """
               box wave() + 1
               """
    ,
     input:    """
               box wave +1
               """
     expected: """
               box wave +1
               """
    ,
     input:    """
               box wave -1
               """
     expected: """
               box wave -1
               """
    ,
     input:    """
               box wave *1
               """
     expected: """
               box wave() *1
               """
    ,
     input:    """
               box wave /1
               """
     expected: """
               box wave() /1
               """
    ,
     input:    """
               box wave * 1
               """
     expected: """
               box wave() * 1
               """
    ,
     input:    """
               box wave / 1
               """
     expected: """
               box wave() / 1
               """
    ,
     # this is correct interpretation, as
     # in coffeescript
     #   a b +c
     # is translated to
     #   a(b(+c));
     input:    """
               box wave +wave
               """
     expected: """
               box wave +wave()
               """
    ,
     input:    """
               box wave+wave
               """
     expected: """
               box wave()+wave()
               """
    ,
     input:    """
               rotate wave times box
               """
     expected: """
               rotate -> (wave()).times @, box
               """
    ,
     input:    """
               rotate 10*wave times box
               """
     expected: """
               rotate -> (10*wave()).times @, box
               """
    ,
     input:    """
               rotate 10 * wave times box
               """
     expected: """
               rotate -> (10 * wave()).times @, box
               """
    ,
     input:    """
               rotate wave * wave times box
               """
     expected: """
               rotate -> (wave() * wave()).times @, box
               """
    ,
     input:    """
               rotates waves * waves timess boxs
               """
     expected: """
               rotates waves * waves timess boxs
               """
    ,
     input:    """
               rotate wave*wave times box
               """
     expected: """
               rotate -> (wave()*wave()).times @, box
               """
    ,
     input:    """
               rotate wave*wave
               box
               """
     expected: """
               rotate wave()*wave()
               box()
               """
    ,
     input:    """
               rotate 2 times box
               """
     expected: """
               rotate -> 2.times @, box
               """
    ,
     notes:    """
               There are two ways to interpret this,
               we pick one
               """
     input:    """
               rotate wave 2 times box
               """
     expected: """
               rotate -> (wave 2).times @, box
               """
    ,
     input:    """
               rotate wave + 2 times box
               """
     expected: """
               rotate -> (wave() + 2).times @, box
               """
    ,
     input:    """
               box 2 times box
               """
     expected: """
               box -> 2.times @, box
               """
    ,
     input:    """
               2 times 3 times box
               """
     expected: """
               2.times @, -> 3.times @, box
               """
    ,
     input:    """
               2 times 3 times 4 times box
               """
     expected: """
               2.times @, -> 3.times @, -> 4.times @, box
               """
    ,
     input:    """
               2 times box 3 times line 2
               """
     expected: """
               2.times @, -> box -> 3.times @, -> line 2
               """
    ,
     input:    """
               box(wave)
               """
     expected: """
               box(wave())
               """
    ,
     input:    """
               box(wave,wave)
               """
     expected: """
               box(wave(),wave())
               """
    ,
     input:    """
               box(wave,wave,wave)
               """
     expected: """
               box(wave(),wave(),wave())
               """
    ,
     input:    """
               a=wave+wave+wave
               """
     expected: """
               a = wave()+wave()+wave()
               """
    ,
     # to be investigated
     #input:    """
     #          rotate(box,peg,line)
     #          """
     #expected: """
     #          rotate(box(), peg, line)
     #          """
    #,
     input:    """
               rotate box peg line
               """
     expected: """
               rotate -> box -> peg line
               """
    ,
     input:    """
               rotate 2 box peg line
               """
     expected: """
               rotate 2, -> box -> peg line
               """
    ,
     input:    """
               rotate 2 + n box peg line
               """
     expected: """
               rotate 2 + n, -> box -> peg line
               """
    ,
     input:    """
               rotate 2 + time box peg line
               """
     expected: """
               rotate 2 + time, -> box -> peg line
               """
    ,
     input:    """
               for i in [0...wave * 2]
               """
     expected: """
               for i in [0...wave() * 2]
               """
    ,
     input:    """
               for i in [0...2*wave]
               """
     expected: """
               for i in [0...2*wave()]
               """
    ,
     # note that this example doesn't make sense
     #input:    """
     #          either = (a,b) -> if random > 0.5 then a() else b()
     #          either box, peg
     #          """
     #expected: """
     #          either = (a,b) -> if random() > 0.5 then a() else b()
     #          either box(), peg
     #          """
    #,
     # note that this example doesn't make sense
     input:    """
               either = (a,b) -> if random > 0.5 then a() else b()
               rotate box, peg
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a() else b()
               rotate box, peg
               """
    ,
     input:    """
               scale 0.3
               a = 3
               move rotate scale 3 box peg line 2
               move 0.1 peg move 0.4 box
               """
     expected: """
               scale 0.3
               a = 3
               move -> rotate -> scale 3, -> box -> peg -> line 2
               move 0.1, -> peg -> move 0.4, box
               """
    ,
     input:    """
               noFill
               for i in [1..20]
               ▶rotate time/100000
               ▶box i/8
               """
     expected: """
               noFill()
               for i in [1..20]
               ▶rotate time/100000
               ▶box i/8
               """
    ,
     input:    """
               noFill
               for i in [1..20] by 5
               ▶rotate time/100000
               ▶box i/8
               """
     expected: """
               noFill()
               for i in [1..20] by 5
               ▶rotate time/100000
               ▶box i/8
               """
    ,
     input:    """
               // yo dawg I heard you like balls so I put a ball inside a ball so you can see balls inside balls
               noFill
               sizes = [1..3]
               ball size for size in sizes when size isnt 3
               """
     expected: """

               noFill()
               sizes = [1..3]
               ball size for size in sizes when size isnt 3
               """
    ,
     input:    """
               noFill
               20.times (i) ->
               ▶rotate time/100000
               ▶box i/8
               """
     expected: """
               noFill()
               20.timesWithVariable @, (i) ->
               ▶rotate time/100000
               ▶box i/8
               """
    ,
     input:    """
               scale 0.1
               shapes = 'box': 1, 'ball': 2, 'peg': 3
               
               for shape, size of shapes
               ▶move 2
               ▶eval(shape+"(" + size+")")
               """
     expected: """
               scale 0.1
               shapes = 'box': 1, 'ball': 2, 'peg': 3
               
               for shape, size of shapes
               ▶move 2
               ▶eval(shape+"(" + size+")")
               """
    ,
     input:    """
               d = 2
               scale 2, d box b, c
               """
     expected: """
               d = 2
               scale 2, d, -> box b, c
               """
    ,
     # This might not be what the user means,
     # but it probably is.
     input:    """
               d = -> 2
               scale 2, d box b, c
               """
     expected: """
               d = -> 2
               scale 2, d(), -> box b, c
               """
    ,
     input:    """
               a = 2
               scale 2, a box b, c
               """
     expected: """
               a = 2
               scale 2, a, -> box b, c
               """
    ,
     input:    """
               either = (a,b) -> if random > 0.5 then a() else b()
               either (->box), (->peg)
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a() else b()
               either (-> box()), (-> peg())
               """
    ,
     input:    """
               either = (a,b) -> if random > 0.5 then a() else b()
               either <box>, <peg>
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a() else b()
               either box, peg
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     input:    """
               either = (a,b) -> if random > 0.5 then a() else b()
               either <box 2>, <peg 2>
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a() else b()
               either ((parametersForBracketedFunctions) -> (box 2, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil))), ((parametersForBracketedFunctions) -> (peg 2, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               """
     failsMootAppends: true
    ,
     input:    """
               either = (a,b) -> if random > 0.5 then a() else b()
               either (->box),(->rect)
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a() else b()
               either (-> box()),(-> rect())
               """
    ,
     input:    """
               rand = (arg) -> random(arg)
               box (rand 2) ball 2
               """
     expected: """
               rand = (arg) -> random(arg)
               box (rand 2), -> ball 2
               """
    ,
     input:    """
               animationStyle paintOver
               noStroke
               rand = -> 255*random
               fill rand, 255*random, 255*random
               50 times
               ▶resetMatrix
               ▶scale 0.4
               ▶move 5-(random 10), 5-(random 10), 5-(random 10)
               ▶ball
               """
     expected: """
               animationStyle paintOver
               noStroke()
               rand = -> 255*random()
               fill rand(), 255*random(), 255*random()
               50.times @, ->
               ▶resetMatrix()
               ▶scale 0.4
               ▶move 5-(random 10), 5-(random 10), 5-(random 10)
               ▶ball()
               """
    ,
     input:    """
               scale rotate box 2 peg 2.3
               """
     expected: """
               scale -> rotate -> box 2, -> peg 2.3
               """
    ,
     input:    """
               rotate box peg 1.1
               """
     expected: """
               rotate -> box -> peg 1.1
               """
    ,
     input:    """
               rotate box peg 1.1
               """
     expected: """
               rotate -> box -> peg 1.1
               """
    ,
     input:    """
               rotate box rotate line 2
               """
     expected: """
               rotate -> box -> rotate -> line 2
               """
    ,
     input:    """
               rotate box line 2
               """
     expected: """
               rotate -> box -> line 2
               """
    ,
     input:    """
               rotate rotate rotate rotate box line 2
               """
     expected: """
               rotate -> rotate -> rotate -> rotate -> box -> line 2
               """
    ,
     input:    """
               2 times rotate box line 2
               """
     expected: """
               2.times @, -> rotate -> box -> line 2
               """
    ,
     input:    """
               rotate rotate box
               """
     expected: """
               rotate -> rotate box
               """
    ,
     input:    """
               10 times rotate scale box
               """
     expected: """
               10.times @, -> rotate -> scale box
               """
    ,
     input:    """
               rotate time/1000
               ✓doOnce
               ▶background 255
               ▶fill 255,0,0
               ✓doOnce ball
               box
               """
     expected: """
               rotate time/1000
               if false
               ▶background 255
               ▶fill 255,0,0
               noOperation
               box()
               """
    ,
     input:    """
               line
               ✓doOnce
               ▶box 1

               line
               ✓doOnce //
               ▶box 1
               """
     expected: """
               line()
               if false
               ▶box 1

               line()
               if false
               ▶box 1
               """
    ,
     input:    """
               line
               ✓doOnce
               ▶box 1

               line
               ✓doOnce//
               ▶box 1
               """
     expected: """
               line()
               if false
               ▶box 1

               line()
               if false
               ▶box 1
               """
    ,
     input:    """
               rotate time
               ✓doOnce
               ▶background 255
               ▶fill 255,0,0
               if true
               ▶✓doOnce ball
               box
               """
     expected: """
               rotate time
               if false
               ▶background 255
               ▶fill 255,0,0
               if true
               ▶noOperation
               box()
               """
    ,
     input:    """
               rotate time/1000
               doOnce
               ▶background 255
               ▶fill 255,0,0
               doOnce ball
               box
               """
     expected: """
               rotate time/1000
               1.times @, ->
               ▶addDoOnce(1); background 255
               ▶fill 255,0,0
               addDoOnce(4); 1.times @, ball
               box()
               """
    ,
     input:    """
               rotate time/1000
               doOnce
               ▶// test
               ▶background 255
               ▶fill 255,0,0
               ✓doOnce -> ball
               box
               """
     expected: """
               rotate time/1000
               1.times @, ->
               ▶addDoOnce(1)
               ▶background 255
               ▶fill 255,0,0
               noOperation
               box()
               """
    ,
     # note that the matrix operations do chain also
     # in this case
     input:    """
               move peg 1.2 move box
               """
     expected: """
               move -> peg 1.2, -> move box
               """
    ,
     input:    """
               rotate
               ▶box
               peg
               """
     expected: """
               rotate ->
               ▶box()
               peg()
               """
    ,
     input:    """
               rotate 2
               ▶box
               peg
               """
     expected: """
               rotate 2, ->
               ▶box()
               peg()
               """
    ,
     input:    """
               rotate
               rotate 2,1,0
               ▶box
               ▶rotate 1
               ▶▶line 3
               ▶▶move
               ▶▶rotate
               ▶▶▶ball 0.6
               """
     expected: """
               rotate()
               rotate 2,1,0, ->
               ▶box()
               ▶rotate 1, ->
               ▶▶line 3
               ▶▶move()
               ▶▶rotate ->
               ▶▶▶ball 0.6
               """
    ,
     notes:    """
               A complex case with nested if then else and
               function definition.
               """
     input:    """
               if true then if true then a = -> ball if true then a = -> rect else line ball
               a
               """
     expected: """
               if true then if true then a = -> ball(); if true then a = -> rect() else line ball
               a()
               """
    ,
     notes:    """
               Check that qualifiers don't span over else
               """
     input:    """
               if true then move rotate box else move line
               """
     expected: """
               if true then move -> rotate box else move line
               """
    ,
     notes:    """
               Some times nested in ifs. The final js,
               consistently with coffeescript, is:
                 if (true) {
                   2..times(function() {
                     box();
                     return line();
                   });
                 } else {
                   peg();
                 }                   
               """
     input:    """
               if true then 2 times box line else peg
               """
     expected: """
               if true then 2.times @, -> box line else peg()
               """
    ,
     notes:    """
               Some more "times nested in ifs". The final js,
               consistently with coffeescript, is:
               if (true) {
                 2..times(function() {
                   box();
                   if (true) {
                     return 2..times(function() {
                       return rect();
                     });
                   }
                 });
               } else {
                 2..times(function() {
                   peg();
                   return ball();
               """
     input:    """
               if true then 2 times box if true then 2 times rect else 2 times peg ball
               """
     expected: """
               if true then 2.times @, box; if true then 2.times @, rect else 2.times @, -> peg ball
               """
    ,
     notes:    """
               """
     input:    """
               2 times if true then ball
               """
     expected: """
               2.times @, -> if true then ball()
               """
    ,
     notes:    """
               """
     input:    """
               2 times if true then ball
               """
     expected: """
               2.times @, -> if true then ball()
               """
    ,
     notes:    """
               note that you cannot have anonymous
               functions in the test in coffeescript,
               i.e. pasting the "expected" below
               into coffeescript gives an error
               """
     input:    """
               if 2 times a then ball
               """
     expected: """
               if 2.times @, -> a then ball()
               """
    ,
     notes:    """
               this example doesn't mean anything
               meaningful...
               """
     input:    """
               if (2 times a) then ball
               """
     expected: """
               if (2.times @, -> a) then ball()
               """
    ,
     notes:    """
               times and qualifiers within an if-then-else
               """
     input:    """
               if random < 0.5 then 2 times rotate box else 3 times move peg
               """
     expected: """
               if random() < 0.5 then 2.times @, -> rotate box else 3.times @, -> move peg
               """
    ,
     notes:    """
               """
     input:    """
               peg move
               ▶box
               peg
               """
     expected: """
               peg -> move ->
               ▶box()
               peg()
               """
    ,
     notes:    """
               """
     input:    """
               a = 3
               rotate 2,a+1+3*(a*2.32+Math.PI) 2+a+Math.PI times box
               peg
               """
     expected: """
               a = 3
               rotate 2,a+1+3*(a*2.32+Math.PI), -> (2+a+Math.PI).times @, box
               peg()
               """
    ,
     notes:    """
               """
     input:    """
               rotate move scale 2 times box
               """
     expected: """
               rotate -> move -> scale -> 2.times @, box
               """
    ,
     notes:    """
               """
     input:    """
               if true then rotate move scale box else rotate move scale 2 times box
               """
     expected: """
               if true then rotate -> move -> scale box else rotate -> move -> scale -> 2.times @, box
               """
    ,
     notes:    """
               """
     input:    """
               if true then rotate move scale 2 times box else rotate move scale box
               """
     expected: """
               if true then rotate -> move -> scale -> 2.times @, box else rotate -> move -> scale box
               """
    ,
     notes:    """
               """
     input:    """
               if true then scale rotate else scale rotate 2 times move
               """
     expected: """
               if true then scale rotate else scale -> rotate -> 2.times @, move
               """
    ,
     notes:    """
               a long chain of matrix operations will tell
               whether there are some trandformations that
               don't quite complete their job.
               """
     input:    """
               if true then rotate move scale scale scale scale move move rotate rotate box else rotate move scale scale scale scale move move rotate rotate 2 times box
               """
     expected: """
               if true then rotate -> move -> scale -> scale -> scale -> scale -> move -> move -> rotate -> rotate box else rotate -> move -> scale -> scale -> scale -> scale -> move -> move -> rotate -> rotate -> 2.times @, box
               """
    ,
     notes:    """
               note that
                 scale(3) ,(-> box());
               would give error in coffeescript
               """
     input:    """
               scale (3) box
               ball
               """
     expected: """
               scale (3), box
               ball()
               """
    ,
     notes:    """
               """
     input:    """
               scale(3) box
               ball
               """
     expected: """
               scale(3); box()
               ball()
               """
    ,
     notes:    """
               """
     input:    """
               scale 2, box
               """
     expected: """
               scale 2, box
               """
    ,
     notes:    """
               """
     input:    """
               scale 2,box
               """
     expected: """
               scale 2, box
               """
    ,
     notes:    """
               """
     input:    """
               scale 2, -> box
               """
     expected: """
               scale 2, box
               """
    ,
     notes:    """
               """
     input:    """
               scale 2, ->box
               """
     expected: """
               scale 2, box
               """
    ,
     notes:    """
               """
     input:    """
               scale 2,->box
               """
     expected: """
               scale 2, box
               """
    ,
     notes:    """
               """
     input:    """
               rotate 1 + wave, -> box
               """
     expected: """
               rotate 1 + wave(), box
               """
    ,
     notes:    """
               """
     input:    """
               localMaterial <box peg 1.1, time rotate ball>
               """
     expected: """
               localMaterial ((parametersForBracketedFunctions) -> (box -> peg 1.1, time, -> rotate -> ball -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               """
     failsMootAppends: true
    ,

     notes:    """
               """
     input:    """
               a = 2

               rotate 2 times box box
               rotate 2 2+2*2 times box
               rotate 2,a 2+2*2 times box
               rotate a+1+3 2 times box
               rotate 2 2 times box
               rotate 2,a+1+3*(a*2.32+Math.PI) 2+a+Math.PI times box
               box a + 3 times rotate peg
               2 times box
               1+1 times box
               peg 2 times box
               n = 2 n times: box
               rotate wave times box
               rotate 10*wave times box
               rotate 10 * wave times box
               wave wave times box
               rotate wave wave times box

               if true then rotate 2 times box box
               if true then rotate 2 2+2*2 times box
               if true then rotate 2,a 2+2*2 times box
               if true then rotate a+1+3 2 times box
               if true then rotate 2 2 times box
               if true then rotate 2,a+1+3*(a*2.32+Math.PI) 2+a+Math.PI times box
               if true then box a + 3 times rotate peg
               if true then 2 times box
               if true then 1+1 times box
               if true then peg 2 times box
               if true then n = 2 n times: box
               if true then rotate wave times box
               if true then rotate 10*wave times box
               if true then rotate 10 * wave times box
               if true then wave wave times box
               if true then rotate wave wave times box

               if true then rotate 2 times box box else rotate 2 times box box
               if true then rotate 2 2+2*2 times box else rotate 2 2+2*2 times box
               if true then rotate 2,a 2+2*2 times box else rotate 2,a 2+2*2 times box
               if true then rotate a+1+3 2 times box else rotate a+1+3 2 times box
               if true then rotate 2 2 times box else rotate 2 2 times box
               if true then rotate 2,a+1+3*(a*2.32+Math.PI) 2+a+Math.PI times box else rotate 2,a+1+3*(a*2.32+Math.PI) 2+a+Math.PI times box
               if true then box a + 3 times rotate peg else box a + 3 times rotate peg
               if true then 2 times box else 2 times box
               if true then 1+1 times box else 1+1 times box
               if true then peg 2 times box else peg 2 times box
               if true then n = 2 n times: box else n = 2 n times: box
               if true then rotate wave times box else rotate wave times box
               if true then rotate 10*wave times box else rotate 10*wave times box
               if true then rotate 10 * wave times box else rotate 10 * wave times box
               if true then wave wave times box else wave wave times box
               if true then rotate wave wave times box else rotate wave wave times box                   """
     expected: """
               a = 2

               rotate -> 2.times @, -> box box
               rotate 2, -> (2+2*2).times @, box
               rotate 2,a, -> (2+2*2).times @, box
               rotate a+1+3, -> 2.times @, box
               rotate 2, -> 2.times @, box
               rotate 2,a+1+3*(a*2.32+Math.PI), -> (2+a+Math.PI).times @, box
               box -> (a + 3).times @, -> rotate peg
               2.times @, box
               (1+1).times @, box
               peg -> 2.times @, box
               n = 2; n.times @, box
               rotate -> (wave()).times @, box
               rotate -> (10*wave()).times @, box
               rotate -> (10 * wave()).times @, box
               (wave wave()).times @, box
               rotate -> (wave wave()).times @, box

               if true then rotate -> 2.times @, -> box box
               if true then rotate 2, -> (2+2*2).times @, box
               if true then rotate 2,a, -> (2+2*2).times @, box
               if true then rotate a+1+3, -> 2.times @, box
               if true then rotate 2, -> 2.times @, box
               if true then rotate 2,a+1+3*(a*2.32+Math.PI), -> (2+a+Math.PI).times @, box
               if true then box -> (a + 3).times @, -> rotate peg
               if true then 2.times @, box
               if true then (1+1).times @, box
               if true then peg -> 2.times @, box
               if true then n = 2; n.times @, box
               if true then rotate -> (wave()).times @, box
               if true then rotate -> (10*wave()).times @, box
               if true then rotate -> (10 * wave()).times @, box
               if true then (wave wave()).times @, box
               if true then rotate -> (wave wave()).times @, box

               if true then rotate -> 2.times @, -> box box else rotate -> 2.times @, -> box box
               if true then rotate 2, -> (2+2*2).times @, box else rotate 2, -> (2+2*2).times @, box
               if true then rotate 2,a, -> (2+2*2).times @, box else rotate 2,a, -> (2+2*2).times @, box
               if true then rotate a+1+3, -> 2.times @, box else rotate a+1+3, -> 2.times @, box
               if true then rotate 2, -> 2.times @, box else rotate 2, -> 2.times @, box
               if true then rotate 2,a+1+3*(a*2.32+Math.PI), -> (2+a+Math.PI).times @, box else rotate 2,a+1+3*(a*2.32+Math.PI), -> (2+a+Math.PI).times @, box
               if true then box -> (a + 3).times @, -> rotate peg else box -> (a + 3).times @, -> rotate peg
               if true then 2.times @, box else 2.times @, box
               if true then (1+1).times @, box else (1+1).times @, box
               if true then peg -> 2.times @, box else peg -> 2.times @, box
               if true then n = 2; n.times @, box else n = 2; n.times @, box
               if true then rotate -> (wave()).times @, box else rotate -> (wave()).times @, box
               if true then rotate -> (10*wave()).times @, box else rotate -> (10*wave()).times @, box
               if true then rotate -> (10 * wave()).times @, box else rotate -> (10 * wave()).times @, box
               if true then (wave wave()).times @, box else (wave wave()).times @, box
               if true then rotate -> (wave wave()).times @, box else rotate -> (wave wave()).times @, box
               """
    ,
     notes:    """
               """
     input:    """
               a = 0
               af = -> 0
               b = true
               bf = -> true
               if a == 0 then line a
               if a != 0 then line a
               if a >= 0 then line a
               if a <= 0 then line a
               if af == 0 then line a
               if af != 0 then line a
               if af >= 0 then line a
               if af <= 0 then line a
               if b and true then line a
               if b or true then line a
               if not b then line a
               if ! b then line a
               if !b then line a
               if bf and true then line a
               if bf or true then line a
               if not bf then line a
               if ! bf then line a
               if !bf then line a
               """
     expected: """
               a = 0
               af = -> 0
               b = true
               bf = -> true
               if a == 0 then line a
               if a != 0 then line a
               if a >= 0 then line a
               if a <= 0 then line a
               if af() == 0 then line a
               if af() != 0 then line a
               if af() >= 0 then line a
               if af() <= 0 then line a
               if b and true then line a
               if b or true then line a
               if not b then line a
               if ! b then line a
               if !b then line a
               if bf() and true then line a
               if bf() or true then line a
               if not bf() then line a
               if ! bf() then line a
               if !bf() then line a
               """
    ,
     notes:    """
               """
     input:    """
               myBoxFunc = <box>
               rotate -> myBoxFunc 1, 2, 3
               """
     expected: """
               myBoxFunc = box
               rotate -> myBoxFunc 1, 2, 3
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               """
     input:    """
               myBoxFunc = <box>
               rotate
               ▶myBoxFunc 1, 2, 3
               """
     expected: """
               myBoxFunc = box
               rotate ->
               ▶myBoxFunc 1, 2, 3
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               """
     input:    """
               myBoxFunc = -> <box>
               rotate myBoxFunc 1, 2, 3
               """
     expected: """
               myBoxFunc = -> box
               rotate myBoxFunc 1, 2, 3
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               """
     input:    """
               myBoxFunc = (a,b,c) -> box a,b,c
               rotate -> myBoxFunc 1, 2, 3
               """
     expected: """
               myBoxFunc = (a,b,c) -> box a,b,c
               rotate -> myBoxFunc 1, 2, 3
               """
    ,
     notes:    """
               """
     input:    """
               myBoxFunc = (a,b,c) -> -> box a,b,c
               rotate myBoxFunc 1, 2, 3
               """
     expected: """
               myBoxFunc = (a,b,c) -> -> box a,b,c
               rotate myBoxFunc 1, 2, 3
               """
    ,
     notes:    """
               """
     input:    """
               myBoxFunc = (a,b,c) -> box a,b,c
               rotate
               ▶myBoxFunc 1, 2, 3
               """
     expected: """
               myBoxFunc = (a,b,c) -> box a,b,c
               rotate ->
               ▶myBoxFunc 1, 2, 3
               """
    ,
     notes:    """
               """
     input:    """
               flickr = (code) -> if random < 0.5 then code()
               flickr <box peg 1.1 2 times rotate ball>
               """
     expected: """
               flickr = (code) -> if random() < 0.5 then code()
               flickr ((parametersForBracketedFunctions) -> (box -> peg 1.1, -> 2.times @, -> rotate -> ball -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               """
     failsMootAppends: true
    ,
     notes:    """
               """
     input:    """
               sin time*10 times
               ▶box
               """
     expected: """
               (sin time*10).times @, ->
               ▶box()
               """
    ,
     notes:    """
               """
     input:    """
               (sin time*10) times
               ▶box
               """
     expected: """
               (sin time*10).times @, ->
               ▶box()
               """
    ,
     notes:    """
               """
     input:    """
               time*100 % 1 times
               ▶box
               """
     expected: """
               (time*100 % 1).times @, ->
               ▶box()
               """
    ,
     notes:    """
               """
     input:    """
               round(wave 0.5) times
               ▶box
               """
     expected: """
               (round(wave 0.5)).times @, ->
               ▶box()
               """
    ,
     notes:    """
               """
     input:    """
               myF = (a)-> sin time*a

               myF 2 times
               ▶box
               """
     expected: """
               myF = (a) -> sin time*a

               (myF 2).times @, ->
               ▶box()
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               myF = ()-> sin time*2

               myF 2 times
               ▶box
               """
     expected: """
               myF = () -> sin time*2

               myF(); 2.times @, ->
               ▶box()
               """
    ,
     notes:    """
               """
     input:    """
               myF = -> sin time*2

               myF 2 times
               ▶box
               """
     expected: """
               myF = -> sin time*2

               myF(); 2.times @, ->
               ▶box()
               """
    ,
     notes:    """
               """
     input:    """
               myF = (a)-> sin time*2
               b = myF +4
               """
     expected: """
               myF = (a) -> sin time*2
               b = myF +4
               """
    ,
     notes:    """
               note that this example would translate
               correctly but it wouldn't work. the translation
               is exactly the same that one would get with
               coffeescript
               """
     input:    """
               myF = ()-> sin time*2
               b = myF -4
               """
     expected: """
               myF = () -> sin time*2
               b = myF -4
               """
    ,
     notes:    """
               note that this example would translate
               correctly but it wouldn't work. the translation
               is exactly the same that one would get with
               coffeescript. See example below for a program
               that indeed would work.
               """
     input:    """
               myF = -> sin time*2
               b = myF -4
               """
     expected: """
               myF = -> sin time*2
               b = myF -4
               """
    ,
     input:    """
               myF = -> sin time*2
               b = myF - 4
               """
     expected: """
               myF = -> sin time*2
               b = myF() - 4
               """
    ,
     notes:    """
               """
     input:    """
               rotate 1
               rotate (wave 0.5) * 0.1 box 2
               """
     expected: """
               rotate 1
               rotate (wave(0.5) * 0.1), -> box 2
               """
    ,
     notes:    """
               """
     input:    """
               a = (val) -> val * 2
               rotate 3, a 1 box 3, 4, a 1
               """
     expected: """
               a = (val) -> val * 2
               rotate 3, a(1), -> box 3, 4, a 1
               """
    ,
     notes:    """
               """
     input:    """
               a = (val) -> val * 2
               rotate 3, wave wave 2 box 3, 4, a 1
               """
     expected: """
               a = (val) -> val * 2
               rotate 3, wave(wave(2)), -> box 3, 4, a 1
               """
    ,
     notes:    """
               """
     input:    """
               a = (val) -> val * 2
               rotate 3, wave pulse / 10 box 3, 4, a 1
               """
     expected: """
               a = (val) -> val * 2
               rotate 3, wave(pulse() / 10), -> box 3, 4, a 1
               """
    ,
     notes:    """
               """
     input:    """
               rotate 3 scale 2 box 3, 4
               """
     expected: """
               rotate 3, -> scale 2, -> box 3, 4
               """
    ,
     notes:    """
               Code blocks being passed to a function,
               one accepting a parameter and the other one
               returning a value
               """
     input:    """
               either = (a,b) -> if random > 0.5 then a 2 else b()
               console.log either <box>, <random>
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a 2 else b()
               console.log either box, random
               """
     notIdempotent: true
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               noFill
               fill red stroke white rect
               ball
               """
     expected: """
               noFill()
               fill red, -> stroke white, rect
               ball()
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               checking that comments on the last line
               are properly stripped
               """
     input:    """
               either = (a,b) -> if random > 0.5 then a() else b() // ouch
               either <box>, <peg> //ouch
               """
     expected: """
               either = (a,b) -> if random() > 0.5 then a() else b() 
               either box, peg 
               """
     notIdempotent: true
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               red box
               """
     expected: """
               fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               rotate red box
               rotate  red box
               """
     expected: """
               rotate -> fill red, box
               rotate -> fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               line red box
               """
     expected: """
               line -> fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               solid red box even when you change
               the number
               """
     input:    """
               fill red,22 red box
               """
     expected: """
               fill red,22, -> fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               fill red,20+5*pulse+sin(time) box 3,5 yellow stroke box
               """
     expected: """
               fill red,20+5*pulse()+sin(time), -> box 3,5, -> stroke yellow, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               red yellow stroke box
               """
     expected: """
               fill red, -> stroke yellow, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               red fill stroke yellow ball
               """
     expected: """
               fill red, -> stroke yellow, ball
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               red fill noStroke peg
               """
     expected: """
               fill red, -> noStroke peg
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               """
     input:    """
               rotate noStroke fill 255*pulse,0,0, 255*pulse box
               """
     expected: """
               rotate -> noStroke -> fill 255*pulse(),0,0, 255*pulse(), box
               """
    ,
     notes:    """
               """
     input:    """
               f = (a,b) -> a
               rotate 2, f f 3,4 box
               rotate 2, f(f(3,4)) box
               fill red,20 box
               """
     expected: """
               f = (a,b) -> a
               rotate 2, f(f(3,4)), box
               rotate 2, f(f(3,4)), box
               fill red,20, box
               """
    ,
     notes:    """
               """
     input:    """
               rotate wave wave wave  0.5 * 0.1 box
               """
     expected: """
               rotate wave(wave(wave(0.5 * 0.1))), box
               """
    ,
     notes:    """
               """
     input:    """
               background black
               rotate noStroke fill 255*pulse 2 box
               """
     expected: """
               background black
               rotate -> noStroke -> fill 255*pulse(2), box
               """
    ,
     notes:    """
               """
     input:    """
               rotate 2, sin sin time 1 times box
               """
     expected: """
               rotate 2, sin(sin(time)), -> 1.times @, box
               """
    ,
     notes:    """
               """
     input:    """
               rotate red fill red stroke box
               """
     expected: """
               rotate -> fill red, -> stroke red, box
               """
     failsMootAppends: true
     failsMootPrepends: true

    ,
     notes:    """
               """
     input:    """
               stroke stroke
               """
     error: "redundant stroke"

    ,
     notes:    """
               """
     input:    """
               fill fill
               """
     error: "redundant fill"

    ,
     notes:    """
               """
     input:    """
               stroke red stroke
               """
     error: "redundant stroke"

    ,
     notes:    """
               """
     input:    """
               fill red fill
               """
     error: "redundant fill"

    ,
     notes:    """
               """
     input:    """
               box fill red stroke box
               """
     error: "missing color"
    ,
     notes:    """
               """
     input:    """
               fill red stroke box
               """
     error: "missing color"

    ,
     notes:    """
               """
     input:    """
               box fill red stroke fill
               """
     error: "missing color"

    ,
     notes:    """
               """
     input:    """
               box fill red stroke stroke
               """
     error: "redundant stroke"

    ,
     notes:    """
               """
     input:    """
               box red red box
               """
     error: "redundant color"

    ,
     notes:    """
               it's a little silly to write this
               but we accept
                 stroke red green box
               so we also accept this
               """
     input:    """
               fill red red box
               """
     expected: """
               fill red, -> fill -> fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               it's a little silly to write this
               but we accept
                 stroke red green box
               so we also accept this
               """
     input:    """
               rotate
               ▶fill red red box
               """
     expected: """
               rotate ->
               ▶fill red, -> fill -> fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               although this code is weird, we do
               allow for users to write stuff like
                 red green stroke box
               and
                 box red peg
               so we also need to accept this
               """
     input:    """
               box red red fill
               """
     expected: """
               box -> fill red, -> fill red
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               
               """
     input:    """
               rotate stroke frame*100%255 red box
               """
     expected: """
               rotate -> stroke frame*100%255, -> fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true

    ,
     notes:    """
               """
     input:    """
               box red fill red box
               """
     error: "missing color command"

    ,
     notes:    """
               """
     input:    """
               red fill red red
               """
     error: "redundant color"

    ,
     notes:    """
               """
     input:    """
               red red fill red
               """
     error: "redundant color"

    ,
     notes:    """
               """
     input:    """
               red red red
               """
     error: "redundant color"

    ,
     notes:    """
               """
     input:    """
               a = (code) -> code()

               a <ball>

               a
               ▶rect
               ▶peg
               """
     expected: """
               a = (code) -> code()

               a ball

               a ->
               ▶rect()
               ▶peg()
               """
     notIdempotent: true
     failsMootAppends: true
     failsMootPrepends: true

    ,
     notes:    """
               """
     input:    """
               skel = (numberOfTimes, code) ->
               ▶for i in [1..numberOfTimes]
               ▶▶rotate i*time scale i noFill
               ▶▶▶code()

               scale 1/4
               skel 10 * wave 0.1
               ▶ball
               """
     expected: """
               skel = (numberOfTimes, code) ->
               ▶for i in [1..numberOfTimes]
               ▶▶rotate i*time, -> scale i, -> noFill ->
               ▶▶▶code()

               scale 1/4
               skel 10 * wave(0.1), ->
               ▶ball()
               """
     failsMootAppends: true
     failsMootPrepends: true

    ,
     notes:    """
               """
     input:    """
               run <box> 2
               """
     expected: """
               run -> box 2
               """
     failsMootAppends: true

    ,
     notes:    """
               """
     input:    """
               a = <box>
               noFill
               rotate run a scale 2 run a
               """
     expected: """
               a = box
               noFill()
               rotate -> run -> a -> scale 2, -> run a
               """
     notIdempotent: true
     failsMootAppends: true
     failsMootPrepends: true

    ,
     notes:    """
               """
     input:    """
               a = (code) -> code()
               a <ball wave>
               """
     expected: """
               a = (code) -> code()
               a ((parametersForBracketedFunctions) -> (ball wave -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               """
     failsMootAppends: true

    ,
     notes:    """
               """
     input:    """
               f = (a,b)-> rotate a run b
               f 2 * sin time, <ball>
               """
     expected: """
               f = (a,b) -> rotate a, -> run b
               f 2 * sin(time), ball
               """
     notIdempotent: true
     failsMootAppends: true

    ,
     notes:    """
               tests more exotic colors
               """
     input:    """
               background black
               rotate noStroke lemonchiffon box
               rotate 4 red stroke rect
               """
     expected: """
               background black
               rotate -> noStroke -> fill lemonchiffon, box
               rotate 4, -> stroke red, rect
               """
     failsMootAppends: true
     failsMootPrepends: true

    ,
     notes:    """
               colors can be on their own with their own
               indented scoping, just like "rotate" and
               alike
               """
     input:    """
               red
               ▶box
               ▶ball
               peg
               """
     expected: """
               fill red , ->
               ▶box()
               ▶ball()
               peg()
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               more color rejigging test of
               lines on their own
               """
     input:    """
               red stroke
               ▶box
               peg
               """
     expected: """
               stroke red , ->
               ▶box()
               peg()
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               more color rejigging test of
               lines starting with tabs
               """
     input:    """
               rotate
               ▶red box
               """
     expected: """
               rotate ->
               ▶fill red, box
               """
     failsMootAppends: true
     failsMootPrepends: true
    ,
     notes:    """
               binding a variable to times 
               """
     input:    """
               noFill wave*3 times with i rotate box i+1
               """
     expected: """
               noFill -> (wave()*3).timesWithVariable @, (i) -> rotate -> box i+1
               """
    ,
     notes:    """
               An organic example,
               using times with binding
               """
     input:    """
               5 times with i
               ▶rotate 0,time,time/5000
               ▶▶move i/5,0,0
               ▶▶3 times with j
               ▶▶▶rotate j
               ▶▶▶box
               """
     expected: """
               5.timesWithVariable @, (i) ->
               ▶rotate 0,time,time/5000, ->
               ▶▶move i/5,0,0
               ▶▶3.timesWithVariable @, (j) ->
               ▶▶▶rotate j
               ▶▶▶box()
               """
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               peg
               times with i
               ▶box 2
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               times with i
               ▶box
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               peg times with i rotate box 2* wave
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               if true then  times with i do that
               """
     error: "how many times?"
    ,
     notes:    """
               Should give error as 'times'
               is missing how many times the
               loop has to go for
               """
     input:    """
               // should give error
               if random() > 0.5 then rotate box else times with i rotate peg true
               """
     error: "how many times?"
    ,
     notes:    """
               Checking that times finds its "number of loops"
               expression correctly.
               """
     input:    """
               a = 2
               box a + 3 times with i rotate peg
               """
     expected: """
               a = 2
               box -> (a + 3).timesWithVariable @, (i) -> rotate peg
               """
    ,
     notes:    """
               Checking "qualifying" rotate
               """
     input:    """
               6 times with i: rotate box
               """
     expected: """
               6.timesWithVariable @, (i) -> rotate box
               """
    ,
     notes:    """
               Checking "qualifying" rotate and times within
               a function definition
               """
     input:    """
               myFunc = -> 20 times with i rotate box
               """
     expected: """
               myFunc = -> 20.timesWithVariable @, (i) -> rotate box
               """
    ,
     notes:    """
               Checking "qualifying" rotate and times within
               if within a function definition with arguments
               """
     input:    """
               myFunc = (a,b) -> if true then 20 times with i rotate box
               """
     expected: """
               myFunc = (a,b) -> if true then 20.timesWithVariable @, (i) -> rotate box
               """
    ,
     notes:    """
               Checking multiple times within if then statement
               """
     input:    """
               if true then 2 times with i box 3 times with j line 2
               """
     expected: """
               if true then 2.timesWithVariable @, (i) -> box -> 3.timesWithVariable @, (j) -> line 2
               """
    ,
     notes:    """
               Checking that separate rotate and primitive
               within a times body remain correctly separated.
               """
     input:    """
               6 times with i: rotate box
               """
     expected: """
               6.timesWithVariable @, (i) -> rotate box
               """
    ,
     notes:    """
               Qualifying rotate within an indented "times" body
               """
     input:    """
               6 times with i:
               ▶rotate box
               """
     expected: """
               6.timesWithVariable @, (i) ->
               ▶rotate box
               """
    ,
     input:    """
               1+1 times with i: rotate box
               """
     expected: """
               (1+1).timesWithVariable @, (i) -> rotate box
               """
    ,
     input:    """
               peg 2 times with i rotate box 2* wave
               """
     expected: """
               peg -> 2.timesWithVariable @, (i) -> rotate -> box 2* wave()
               """
    ,
     input:    """
               n = 2 n times with i: rotate box
               """
     expected: """
               n = 2; n.timesWithVariable @, (i) -> rotate box
               """
     notIdempotent: true # because of the semicolon
    ,
     input:    """
               n = 2 (n+0).times with i rotate box()
               """
     expected: """
               n = 2; (n+0).timesWithVariable @, (i) -> rotate box
               """
     notIdempotent: true # because of the semicolon
    ,
     input:    """
               box box   2 times with i: rotate peg 1.3
               """
     expected: """
               box -> box -> 2.timesWithVariable @, (i) -> rotate -> peg 1.3
               """
    ,
     input:    """
               if random > 0.5 then 3 times with i: rotate box else 3 times with i rotate 2 times with k: peg 1
               """
     expected: """
               if random() > 0.5 then 3.timesWithVariable @, (i) -> rotate box else 3.timesWithVariable @, (i) -> rotate -> 2.timesWithVariable @, (k) -> peg 1
               """
    ,
     input:    """
               if true then 3 times with i rotate box
               """
     expected: """
               if true then 3.timesWithVariable @, (i) -> rotate box
               """
    ,
     input:    """
               (9+0).times with i -> rotate box
               """
     expected: """
               (9+0).timesWithVariable @, (i) -> rotate box
               """
    ,
     input:    """
               if random() > 0.5 then rotate box else 3 times with i rotate peg 1
               """
     expected: """
               if random() > 0.5 then rotate box else 3.timesWithVariable @, (i) -> rotate -> peg 1
               """
    ,
     input:    """
               if random() > 0.5 then rotate 1 + wave box else 3 times with i rotate peg 1
               """
     expected: """
               if random() > 0.5 then rotate 1 + wave(), box else 3.timesWithVariable @, (i) -> rotate -> peg 1
               """
    ,
     input:    """
               // testing whether mangled accross multiple lines
               if random() > 0.5 then box
               2 times with i: box
               2 times with i: rotate box
               """
     expected: """
               
               if random() > 0.5 then box()
               2.timesWithVariable @, (i) -> box()
               2.timesWithVariable @, (i) -> rotate box
               """
    ,
     input:    """
               // testing whether mangled accross multiple lines
               6 times with i: rotate box
               6 times with i:
               ▶rotate box
               """
     expected: """

               6.timesWithVariable @, (i) -> rotate box
               6.timesWithVariable @, (i) ->
               ▶rotate box
               """
    ,
     input:    """
               2 times with i rotate box wave wave
               """
     expected: """
               2.timesWithVariable @, (i) -> rotate -> box wave wave()
               """
    ,
     input:    """
               2 times with i: box
               """
     expected: """
               2.timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               2 times with i: rotate box
               """
     expected: """
               2.timesWithVariable @, (i) -> rotate box
               """
    ,
     input:    """
               2 times with i rotate box wave
               """
     expected: """
               2.timesWithVariable @, (i) -> rotate -> box wave()
               """
    ,
     input:    """
               2 times with i: rotate box wave
               """
     expected: """
               2.timesWithVariable @, (i) -> rotate -> box wave()
               """
    ,
     input:    """
               2 times with i: move rotate wave box
               """
     expected: """
               2.timesWithVariable @, (i) -> move -> rotate wave(), box
               """
    ,
     input:    """
               rotate wave times with i box
               """
     expected: """
               rotate -> (wave()).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               rotate 10*wave times with i box
               """
     expected: """
               rotate -> (10*wave()).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               rotate 10 * wave times with i box
               """
     expected: """
               rotate -> (10 * wave()).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               rotate wave * wave times with i box
               """
     expected: """
               rotate -> (wave() * wave()).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               rotates waves * waves timess with i boxs
               """
     expected: """
               rotates waves * waves timess with i boxs
               """
    ,
     input:    """
               rotate wave*wave times with i box
               """
     expected: """
               rotate -> (wave()*wave()).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               rotate 2 times with i box
               """
     expected: """
               rotate -> 2.timesWithVariable @, (i) -> box()
               """
    ,
     notes:    """
               There are two ways to interpret this,
               we pick one
               """
     input:    """
               rotate wave 2 times with i box
               """
     expected: """
               rotate -> (wave 2).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               rotate wave + 2 times with i box
               """
     expected: """
               rotate -> (wave() + 2).timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               box 2 times with i box
               """
     expected: """
               box -> 2.timesWithVariable @, (i) -> box()
               """
    ,
     input:    """
               2 times with i 3 times with k box
               """
     expected: """
               2.timesWithVariable @, (i) -> 3.timesWithVariable @, (k) -> box()
               """
    ,
     input:    """
               2 times with i 3 times with j 4 times with k box
               """
     expected: """
               2.timesWithVariable @, (i) -> 3.timesWithVariable @, (j) -> 4.timesWithVariable @, (k) -> box()
               """
    ,
     input:    """
               2 times with i box 3 times with j line 2
               """
     expected: """
               2.timesWithVariable @, (i) -> box -> 3.timesWithVariable @, (j) -> line 2
               """
    ,
     input:    """
               2 times with i rotate box line 2
               """
     expected: """
               2.timesWithVariable @, (i) -> rotate -> box -> line 2
               """
    ,
     input:    """
               10 times with i rotate scale box
               """
     expected: """
               10.timesWithVariable @, (i) -> rotate -> scale box
               """
    ,
     notes:    """
               Some times nested in ifs. The final js,
               consistently with coffeescript, is:
                 if (true) {
                   2..times(function() {
                     box();
                     return line();
                   });
                 } else {
                   peg();
                 }                   
               """
     input:    """
               if true then 2 times with i box line else peg
               """
     expected: """
               if true then 2.timesWithVariable @, (i) -> box line else peg()
               """
    ,
     notes:    """
               Some more "times nested in ifs". The final js,
               consistently with coffeescript, is:
               if (true) {
                 2..times(function() {
                   box();
                   if (true) {
                     return 2..times(function() {
                       return rect();
                     });
                   }
                 });
               } else {
                 2..times(function() {
                   peg();
                   return ball();
               """
     input:    """
               if true then 2 times with i box if true then 2 times with j rect else 2 times with k peg ball
               """
     expected: """
               if true then 2.timesWithVariable @, (i) -> box(); if true then 2.timesWithVariable @, (j) -> rect() else 2.timesWithVariable @, (k) -> peg ball
               """
    ,
     notes:    """
               """
     input:    """
               2 times with i if true then ball
               """
     expected: """
               2.timesWithVariable @, (i) -> if true then ball()
               """
    ,
     notes:    """
               """
     input:    """
               2 times with i if true then ball
               """
     expected: """
               2.timesWithVariable @, (i) -> if true then ball()
               """
    ,
     notes:    """
               note that you cannot have anonymous
               functions in the test in coffeescript,
               i.e. pasting the "expected" below
               into coffeescript gives an error
               """
     input:    """
               if 2 times with i a then ball
               """
     expected: """
               if 2.timesWithVariable @, (i) -> a then ball()
               """
    ,
     notes:    """
               this example doesn't mean anything
               meaningful...
               """
     input:    """
               if (2 times with i a) then ball
               """
     expected: """
               if (2.timesWithVariable @, (i) -> a) then ball()
               """
    ,
     notes:    """
               times and qualifiers within an if-then-else
               """
     input:    """
               if random < 0.5 then 2 times with i rotate box else 3 times with j move peg
               """
     expected: """
               if random() < 0.5 then 2.timesWithVariable @, (i) -> rotate box else 3.timesWithVariable @, (j) -> move peg
               """
    ,
     notes:    """
               the parser implementation accepts the notation of times
               without the dot and with the arrow, so
               matching that
               """
     input:    """
               2 times -> box 4
               """
     expected: """
               2.times @, -> box 4
               """
    ,
     notes:    """
               the parser implementation accepts the notation of times
               without the dot and with the arrow, so
               matching that
               """
     input:    """
               2 times ->
               ▶box 4
               """
     expected: """
               2.times @, ->
               ▶box 4
               """
    ,
     notes:    """
               the specs supported chevrons for making
               user's life easier
               """
     input:    """
               rotate 2, 3 >> box
               """
     expected: """
               rotate 2, 3, box
               """
     failsMootPrepends: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               transforms = [<rotate>, <scale>, <fill blue>]
               randomTransforms = transforms.filter (x) -> random > 0.5
               drawThis = [<box>].concat randomTransforms
               drawThisFunction = drawThis.reduce (acc,x) -> -> x(acc)
               drawThisFunction()
               """
     expected: """
               transforms = [rotate, scale, ((parametersForBracketedFunctions) -> (fill blue, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))]
               randomTransforms = transforms.filter (x) -> random() > 0.5
               drawThis = [box].concat randomTransforms
               drawThisFunction = drawThis.reduce (acc,x) -> -> x(acc)
               drawThisFunction()
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               a = <box 1>
               b = <rotate ball>
               a b
               move
               b a
               """
     expected: """
               a = ((parametersForBracketedFunctions) -> (box 1, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               b = ((parametersForBracketedFunctions) -> (rotate -> ball -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               a b
               move()
               b a
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               a = <fill red>
               b= <box>
               a b
               move
               b a
               """
     expected: """
               a = ((parametersForBracketedFunctions) -> (fill red, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               b = box
               a b
               move()
               b a
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               a = <box 1>
               b = <rotate ball>
               a b
               move
               b a
               """
     expected: """
               a = ((parametersForBracketedFunctions) -> (box 1, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               b = ((parametersForBracketedFunctions) -> (rotate -> ball -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               a b
               move()
               b a
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               noFill
               [1..2].map (i) -> box i
               """
     expected: """
               noFill()
               [1..2].map (i) -> box i
               """
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               [<box>, <line>, <peg>].map (i) -> rotate i
               """
     expected: """
               [box, line, peg].map (i) -> rotate i
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               primitives = [<box>, <line>, <peg>, <ball>]
               selected = primitives.filter (x) -> random > 0.5
               selected.map (i) -> i()
               """
     expected: """
               primitives = [box, line, peg, ball]
               selected = primitives.filter (x) -> random() > 0.5
               selected.map (i) -> i()
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               drawThis = [<box>, <scale>,<rotate>].reduce (acc,x) -> -> x(acc)
               drawThis()
               """
     expected: """
               drawThis = [box, scale,rotate].reduce (acc,x) -> -> x(acc)
               drawThis()
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               drawPieces = [<box>, <move>,<ball>]
               if random > 0.5
               ▶drawThis = drawPieces.reduce (acc,x) -> -> x(acc)
               else
               ▶drawThis = drawPieces.reduceRight (acc,x) -> -> x(acc)
               drawThis()
               """
     expected: """
               drawPieces = [box, move, ball]
               if random() > 0.5
               ▶drawThis = drawPieces.reduce (acc,x) -> -> x(acc)
               else
               ▶drawThis = drawPieces.reduceRight (acc,x) -> -> x(acc)
               drawThis()
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               drawPieces = [<box>, <move>,<ball>]
               rotate
               ▶if random > 0.5
               ▶▶drawThis = drawPieces.reduce (acc,x) -> -> x(acc)
               ▶else
               ▶▶drawThis = drawPieces.reduceRight (acc,x) -> -> x(acc)
               ▶drawThis()
               """
     expected: """
               drawPieces = [box, move, ball]
               rotate ->
               ▶if random() > 0.5
               ▶▶drawThis = drawPieces.reduce (acc,x) -> -> x(acc)
               ▶else
               ▶▶drawThis = drawPieces.reduceRight (acc,x) -> -> x(acc)
               ▶drawThis()
               """
     notIdempotent: true
     failsMootAppends: true

    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               rotate
               ▶box
               peg

               a = <move 1>
               box a ball
               """
     expected: """
               rotate ->
               ▶box()
               peg()

               a = ((parametersForBracketedFunctions) -> (move 1, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               box -> a ball
               """
     notIdempotent: true
     failsMootAppends: true

    ,
     notes:    """
               testing some more advanced higher-order-functions
               examples
               """
     input:    """
               above  = <move 0,-0.5,0>
               box above ball above peg
               """
     expected: """
               above = ((parametersForBracketedFunctions) -> (move 0,-0.5,0, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))
               box -> above -> ball -> above peg
               """
     notIdempotent: true
     failsMootAppends: true
    ,
     notes:    """
               tests that nothing inside strings undergoes
               any processing
               """
     input:    """
               F = -> box
               s = "F-"
               k = 'F'
               """
     expected: """
               F = -> box()
               s = "F-"
               k = 'F'
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               tests avoidLastArgumentInvocationOverflowing
               substitutions also work with a dangling
               functions
               """
     input:    """
               scale 2, wave time peg
               ▶scale ball
               """
     expected: """
               scale 2, wave(time), -> peg ->
               ▶scale ball
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               tests avoidLastArgumentInvocationOverflowing
               substitutions also work with a dangling
               functions
               """
     input:    """
               scale 2, wave 2 peg
               ▶scale 2, wave 2 ball
               """
     expected: """
               scale 2, wave(2), -> peg ->
               ▶scale 2, wave(2), ball
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               """
     input:    """
               flashing = <if random > 0.5 then rotate else scale>
               flashing ball
               box
               """
     expected: """
               flashing = ifFunctional(random() > 0.5 ,rotate, scale)
               flashing ball
               box()
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               """
     input:    """
               flashing = <if random > 0.5 then scale 0>
               flashing ball
               box
               """
     expected: """
               flashing = ifFunctional(random() > 0.5 ,((parametersForBracketedFunctions) -> (scale 0, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil))))
               flashing ball
               box()
               """
     notIdempotent: false
     failsMootAppends: false

    ,
     notes:    """
               """
     input:    """
               ball
               ▶box
               """
     expected: """
               ball ->
               ▶box()
               """
     notIdempotent: false
     failsMootAppends: false

    ,
     notes:    """
               """
     input:    """
               flashing = <if random > 0.5 then scale 0>
               rotating = <rotate>
               flashing
               ▶ball
               ▶rotating box
               rotate 2 peg 0.7
               """
     expected: """
               flashing = ifFunctional(random() > 0.5 ,((parametersForBracketedFunctions) -> (scale 0, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil))))
               rotating = rotate
               flashing ->
               ▶ball()
               ▶rotating box
               rotate 2, -> peg 0.7
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               """
     input:    """
               flashing = <if random < 0.5 then scale 0 else scale 2>
               flashing
               ball
               """
     expected: """
               flashing = ifFunctional(random() < 0.5 ,((parametersForBracketedFunctions) -> (scale 0, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil))), ((parametersForBracketedFunctions) -> (scale 2, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil))))
               flashing()
               ball()
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               """
     input:    """
               flashing = <if random < 0.5 then scale>
               flashing
               ball
               """
     expected: """
               flashing = ifFunctional(random() < 0.5 ,scale)
               flashing()
               ball()
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               """
     input:    """
               flashing = <if random < 0.5 then scale 0>
               flashing
               ball
               """
     expected: """
               flashing = ifFunctional(random() < 0.5 ,((parametersForBracketedFunctions) -> (scale 0, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil))))
               flashing()
               ball()
               """
     notIdempotent: false
     failsMootAppends: false
    ,
     notes:    """
               """
     input:    """
               F = <box> 
               a = <F>
               run a
               """
     expected: """
               F = box 
               a = F
               run a
               """
     notIdempotent: false
     failsMootAppends: false

  ]

  # We separate Commands from Expressions here.
  # Expressions return a value that is potentially
  # useful, while Stataments just change some sort
  # of state but don't return anything useful.
  # For example you can say
  #   wave + 1; scale wave
  # but not
  #   box + 1; scale box
  # hence, wave is an expression while box is
  # a command.
  # Note that actually in
  # coffeescript everything returns a value,
  # only in our case we really don't know what to
  # do with return values of many functions.
  # The explanation of why we need this separation
  # is in the "implicit function" transformations
  # code.
  qualifyingCommands: [
    # Matrix ops
    "rotate"
    "move"
    "scale"
    # Color and drawing styles
    "fill"
    "stroke"
    "noFill"
    "noStroke"
  ]
  primitives: [
    # Geometry
    "rect"
    "line"
    "box"
    "ball"
    "peg"
    # Others
    "run"
  ]
  commandsExcludingScaleRotateMove: [
    # Geometry
    "ballDetail"
    # Matrix manipulation other than scale rotate move
    "pushMatrix"
    "popMatrix"
    "resetMatrix"
    # Sound
    "bpm"
    "play"
    # Color and drawing styles
    "strokeSize"
    "animationStyle"
    "background"
    "simpleGradient"
    "colorMode"
    # Lighting
    # "ambient""reflect" "refract"
    "lights"
    "noLights"
    "ambientLight"
    "pointLight"
    # Server connections
    "connect"
  ]
  colorCommands: [
    "fill"
    "stroke"      
  ]

  expressions: [
    # Calculations
    "abs"
    "ceil"
    "constrain"
    "dist"
    "exp"
    "floor"
    "lerp"
    "log"
    "mag"
    "map"
    "max"
    "min"
    "norm"
    "pow"
    "round"
    "sq"
    "sqrt"
    # Trigonometry
    "acos"
    "asin"
    "atan"
    "atan2"
    "cos"
    "degrees"
    "radians"
    "sin"
    "tan"
    "wave"
    "beat"
    "pulse"
    # Random
    "random"
    "randomSeed"
    "noise"
    "noiseDetail"
    "noiseSeed"
    # Color
    "color"
  ]


  constructor: ->
    @qualifyingCommandsRegex = @qualifyingCommands.join "|"
    @primitivesRegex = @primitives.join "|"
    @primitivesAndMatrixRegex = @qualifyingCommandsRegex + "|" + @primitivesRegex
    @allCommandsRegex = (@commandsExcludingScaleRotateMove.join "|") +
      "|" + @qualifyingCommandsRegex +
      "|" + @primitivesRegex
    @expressionsRegex = @expressions.join "|"

    # build the regex for the colour literals
    @colorsRegex = ""
    colourLiterals = new ColourLiterals
    for key of colourLiterals.colourNamesValues
      if colourLiterals.colourNamesValues.hasOwnProperty key
        @colorsRegex = @colorsRegex + "|"+key
    # delete the pre-pended pipe character
    @colorsRegex = @colorsRegex.substring(1, @colorsRegex.length)

    @colorsCommandsRegex = @colorCommands.join "|"

  ##
  ## Stops ticked doOnce blocks from running
  ##
  ## doOnce statements which have a tick mark next to them
  ## are not run. This is achieved by replacing the line with
  ## the "doOnce" with "if false" or "//" depending on whether
  ## the doOnce is a multiline or an inline one, like so:
  ##
  ##      ✓doOnce
  ##        background 255
  ##        fill 255,0,0
  ##      ✓doOnce ball
  ##      becomes:
  ##      if false
  ##        background 255
  ##        fill 255,0,0
  ##      //doOnce ball
  ##
  ## @param {string} code    the code to re-write
  ##
  ## @returns {string}
  ##
  removeTickedDoOnce: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # doOnce multiline case
    code = code.replace(/^(\s*)✓[ ]*doOnce[ \t]*$/gm, "$1if false")
    # doOnce single-line case
    # note that you can't just delete the line because it might be
    # hanging below an if statement so you need a fake command
    # there.
    code = code.replace(/^(\s*)✓[ ]*doOnce[ \t]+.*$/gm, "$1noOperation")

    if detailedDebug then console.log "removeTickedDoOnce\n" + code + " error: " + error
    if code.indexOf("✓") != -1
      return [undefined,"✓ must be next to a doOnce"]
    return [code, error]

  # strings shouldn't undergo any transformation
  # so we use replace all the strings with
  # references to a table, which we'll replace back
  # later with the original strings.
  # This code is adapted from Processing.js
  # (ref: "codeWoStrings" and "injectStrings")
  removeStrings: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    stringsTable = []
    codeWithoutStrings = code.replace(/("(?:[^"\\\n]|\\.)*")|('(?:[^'\\\n]|\\.)*')/g, (all, quoted, aposed) ->
      index = stringsTable.length
      stringsTable.push all
      return "'STRINGS_TABLE>" + index + "<STRINGS_TABLE'"
    )

    return [codeWithoutStrings, stringsTable, error]

  # replaces strings and regexs keyed by index with an array of strings
  # see "removeStrings" function
  injectStrings: (code, stringsTable, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace /'STRINGS_TABLE>(\d+)<STRINGS_TABLE'/g, (all, index) ->
      val = stringsTable[index]
      return val

    return [code, error]



  addTracingInstructionsToDoOnceBlocks: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # ADDING TRACING INSTRUCTION TO THE DOONCE BLOCKS
    # each doOnce block is made to start with an instruction that traces whether
    # the block has been run or not. This allows us to put back the tick where
    # necessary, so the doOnce block is not run again.
    # Example - let's say one pastes in this code:
    #
    #      doOnce
    #        background 255
    #        fill 255,0,0
    #
    #      doOnce ball
    #
    # it becomes:
    #
    #      1.times ->
    #        addDoOnce(1); background 255
    #        fill 255,0,0
    #
    #      ;addDoOnce(4);
    #      1.times -> ball
    #
    # So: if there is at least one doOnce
    #   split the source in lines
    #   add line numbers tracing instructions so we can track which
    #   ones have been run regroup the lines into a single string again
    #
    elaboratedSourceByLine = undefined
    if code.indexOf("doOnce") > -1
      
      #alert("a doOnce is potentially executable")
      elaboratedSourceByLine = code.split("\n")
      
      #alert('splitting: ' + elaboratedSourceByLine.length )
      for eachLine in [0...elaboratedSourceByLine.length]
        
        #alert('iterating: ' + eachLine )
        
        # add the line number tracing instruction to inline case
        elaboratedSourceByLine[eachLine] =
          elaboratedSourceByLine[eachLine].replace(
            /(^|\s+)doOnce[ \t]+(.+)$/g,
            "$1;addDoOnce(" + eachLine + "); 1.times -> $2")
        
        # add the line number tracing instruction to multiline case
        if /(^|\s+)doOnce[ \t]*$/g.test(elaboratedSourceByLine[eachLine])
          
          #alert('doOnce multiline!')
          elaboratedSourceByLine[eachLine] =
            elaboratedSourceByLine[eachLine].replace(
              /(^|\s+)doOnce[ \t]*$/g, "$11.times ->")

          elaboratedSourceByLine[eachLine + 1] =
            elaboratedSourceByLine[eachLine + 1].replace(
              /^(\s*)(.*)$/g, "$1addDoOnce(" + eachLine + "); $2")
      code = elaboratedSourceByLine.join "\n"
    
    #alert('soon after replacing doOnces'+code)
    return [code, error]

  doesProgramContainStringsOrComments: (code) ->
    characterBeingExamined = undefined
    nextCharacterBeingExamined = undefined
    while code.length
      characterBeingExamined = code.charAt(0)
      nextCharacterBeingExamined = code.charAt(1)
      if characterBeingExamined is "'" or
          characterBeingExamined is "\"" or
          (characterBeingExamined is "/" and
            (nextCharacterBeingExamined is "*" or
            nextCharacterBeingExamined is "/"))
        return true
      code = code.slice(1)

  stripCommentsAndStrings: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, undefined, error] if error?

    # for some strange reason the comments on the last line
    # are not stripped, so adding a new line which we'll
    # then strip off
    code = code + "\n"

    codeWithoutComments = undefined
    codeWithoutStringsOrComments = undefined
    
    # check whether the program potentially
    # contains strings or comments
    # if it doesn't then we can do some
    # simple syntactic checks that are likely
    # to be much faster than attempting a
    # coffescript to javascript translation
    
    # let's do a quick check:
    # these groups of characters should be in even number:
    # ", ', (), {}, []
    # Note that this doesn't check nesting, so for example
    # [{]} does pass the test.
    if @doesProgramContainStringsOrComments(code)
      
      # OK the program contains comments and/or strings
      # so this is what we are going to do:
      # first we remove all the comments for good
      # then we create a version without the strings
      # so we can perform some basic syntax checking.
      # Note that when we remove the comments we also need to
      # take into account strings because otherwise we mangle a line like
      # print "frame/100 //"
      # where we need to now that that single comment is actually the content
      # of a string.
      # modified from Processing.js (search for: "masks strings and regexs")
      # this is useful to remove all comments but keeping all the strings
      # the difference is that here I don't treat regular expressions.
      # Note that string take precedence over comments i.e.
      #   "lorem ipsum //"
      # is a string, not half a string with a quote in a comment
      # get rid of the comments for good.
      # note the use of coffeescripts' "block regular expressions" here,
      # and note that there is no need to escape "/" with "\/",
      # see https://github.com/jashkenas/coffee-script/issues/2358
      code = code.replace(
        ///
        ("(?:[^"\\\n]|\\.)*")|
        ('(?:[^'\\\n]|\\.)*')|
        (//[^\n]*\n)|
        (/\*(?:(?!\*/)(?:.|\n))*\*/)
        ///g,
          (all, quoted, aposed, singleComment, comment) ->
            numberOfLinesInMultilineComment = undefined
            rebuiltNewLines = undefined
            cycleToRebuildNewLines = undefined
            
            # strings are kept as they are
            return quoted  if quoted
            return aposed  if aposed
            
            # preserve the line because
            # the doOnce mechanism needs to retrieve
            # the line where it was
            return "\n"  if singleComment
            
            # eliminate multiline comments preserving the lines
            numberOfLinesInMultilineComment = comment.split("\n").length - 1
            rebuiltNewLines = ""
            for cycleToRebuildNewLines in [0...numberOfLinesInMultilineComment]
              rebuiltNewLines = rebuiltNewLines + "\n"
            rebuiltNewLines
      )
      codeWithoutComments = code
      
      # in the version we use for syntax checking we delete all the strings
      codeWithoutStringsOrComments =
        code.replace(/("(?:[^"\\\n]|\\.)*")|('(?:[^'\\\n]|\\.)*')/g, "")
    else
      codeWithoutStringsOrComments = code
      codeWithoutComments = code

    # taking away the new line we added to
    # work around the fact that comments on the last
    # line are not stripped
    codeWithoutComments = code.substring(0, code.length - 1)

    return [codeWithoutComments, codeWithoutStringsOrComments, error]

  checkBasicSyntax: (code, codeWithoutStringsOrComments, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?


    aposCount = 0
    quoteCount = 0
    roundBrackCount = 0
    curlyBrackCount = 0
    squareBrackCount = 0
    characterBeingExamined = undefined
    reasonOfBasicError = undefined
    while codeWithoutStringsOrComments.length
      characterBeingExamined = codeWithoutStringsOrComments.charAt(0)
      if characterBeingExamined is "'"
        aposCount += 1
      else if characterBeingExamined is "\""
        quoteCount += 1
      else if characterBeingExamined is "(" or characterBeingExamined is ")"
        roundBrackCount += 1
      else if characterBeingExamined is "{" or characterBeingExamined is "}"
        curlyBrackCount += 1
      else if characterBeingExamined is "[" or characterBeingExamined is "]"
        squareBrackCount += 1
      else if characterBeingExamined is ";"
        return [undefined,"break line instead of using ';'"]
      codeWithoutStringsOrComments = codeWithoutStringsOrComments.slice(1)
    
    # according to jsperf, the fastest way to check if number is even/odd
    if aposCount & 1 or quoteCount & 1 or roundBrackCount & 1 or
        curlyBrackCount & 1 or squareBrackCount & 1
      programHasBasicError = true
      reasonOfBasicError = ''

      reasonOfBasicErrorMissing = ''
      reasonOfBasicErrorMissing = reasonOfBasicErrorMissing + "', "  if aposCount & 1
      reasonOfBasicErrorMissing = reasonOfBasicErrorMissing + "\", "  if quoteCount & 1

      if (aposCount & 1) or (quoteCount & 1)
        reasonOfBasicErrorMissing =  "Missing " + reasonOfBasicErrorMissing
        reasonOfBasicErrorMissing = reasonOfBasicErrorMissing.substring(0, reasonOfBasicErrorMissing.length - 2)

      reasonOfBasicErrorUnbalanced = ''
      reasonOfBasicErrorUnbalanced = reasonOfBasicErrorUnbalanced + "(), "  if roundBrackCount & 1
      reasonOfBasicErrorUnbalanced = reasonOfBasicErrorUnbalanced + "{}, "  if curlyBrackCount & 1
      reasonOfBasicErrorUnbalanced = reasonOfBasicErrorUnbalanced + "[], "  if squareBrackCount & 1

      if (roundBrackCount & 1) or (curlyBrackCount & 1) or (squareBrackCount & 1)
        reasonOfBasicErrorUnbalanced = "Unbalanced " + reasonOfBasicErrorUnbalanced
        reasonOfBasicErrorUnbalanced = reasonOfBasicErrorUnbalanced.substring(0, reasonOfBasicErrorUnbalanced.length - 2)

      reasonOfBasicError = reasonOfBasicErrorMissing + " " + reasonOfBasicErrorUnbalanced
      return [undefined,reasonOfBasicError]
    
    # no comments or strings were found, just return the same string
    # that was passed
    return [code, error]

  ##
  ## Some of the functions can be used with postfix notation
  ##
  ## e.g.
  ##
  ##      60 bpm
  ##      red fill
  ##      yellow stroke
  ##      black background
  ##
  ## We need to switch this round before coffee script compilation
  ###
  adjustPostfixNotations: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # red background
    # red fill;box

    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace(/(\d+)[ ]+bpm(\s|$|;)/g, "bpm $1$2")
    code = code.replace(/([a-zA-Z]+)[ ]+fill(\s|$|;)/g, "fill $1$2")
    code = code.replace(/([a-zA-Z]+)[ ]+stroke(\s|$|;)/g, "stroke $1$2")
    code = code.replace(/([a-zA-Z]+)[ ]+background(\s|$|;)/g, "background $1$2")
    return [code, error]
  ###

  normaliseCode:(code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    #code = code.replace(/;[ ]+/gm, "; ")
    code = code.replace(/[ ];/gm, "; ")
    if detailedDebug then console.log "normalise-1:\n" + code + " error: " + error
    code = code.replace(/;$/gm, "")
    if detailedDebug then console.log "normalise-2:\n" + code + " error: " + error
    code = code.replace(/;([^ \r\n])/gm, "; $1")
    if detailedDebug then console.log "normalise-3:\n" + code + " error: " + error
    return [code, error]

  #   a -> b -> c()
  # is just the same as
  #   a -> b c
  # and, similarly,
  #   a -> b 2, -> c()
  # is just the same as
  #   a -> b 2, c
  simplifyFunctionDoingSimpleInvocation:(code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace(/([\w\d]|,)[\t ]*->[\t ]*([\w\d]*)[\t ]*\([\t ]*\)/gm, "$1 $2")
    if detailedDebug then console.log "simplifyFunctionDoingSimpleInvocation-1:\n" + code + " error: " + error
    return [code, error]

  # sometimes you are left with something like
  #   a = (F)
  # where F is a function.
  # simplify that to
  #   a = F
  simplifyFunctionsAloneInParens:(code, error, userDefinedFunctions, bracketsVariables) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    functionsRegex = @allCommandsRegex + userDefinedFunctions + bracketsVariables

    rx = RegExp("\\([ \\t]*(" + functionsRegex + ")[ \\t]*\\)[ \\t]*$",'gm')
    #console.log rx
    code = code.replace(rx, "$1")


    if detailedDebug then console.log "simplifyFunctionsAloneInParens-1:\n" + code + " error: " + error
    return [code, error]



  # these transformations are supposed to take as input
  # working coffeescript code and give as output
  # beautified and "normalised" coffeescript code
  # with the same exact meaning.
  # TODO Some of these beautification that depend on the () being
  # there are actually critical for the transformed code to work.
  # so they should be moved out of this function.

  beautifyCode:(code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace(/\.times[\\t ]+/gm, ".times ")
    if detailedDebug then console.log "beautifyCode--1:\n" + code + " error: " + error
    code = code.replace(/\.times[\\t ]+with[\\t ]+/gm, ".times with ")
    if detailedDebug then console.log "beautifyCode-0:\n" + code + " error: " + error
    code = code.replace(/->(?![ \t])/gm, "-> ")
    if detailedDebug then console.log "beautifyCode-1:\n" + code + " error: " + error
    code = code.replace(/->[\t ;]+/gm, "-> ")
    if detailedDebug then console.log "beautifyCode-2:\n" + code + " error: " + error
    code = code.replace(/->[\t ]+$/gm, "->")
    if detailedDebug then console.log "beautifyCode-3:\n" + code + " error: " + error
    code = code.replace(/if[\t ;]+/gm, "if ")
    if detailedDebug then console.log "beautifyCode-4:\n" + code + " error: " + error
    code = code.replace(/then[\t ;]+/gm, "then ")
    if detailedDebug then console.log "beautifyCode-5:\n" + code + " error: " + error
    code = code.replace(/else[\t ;]+/gm, "else ")
    if detailedDebug then console.log "beautifyCode-6:\n" + code + " error: " + error
    code = code.replace(/;[\t ]+/gm, "; ")
    if detailedDebug then console.log "beautifyCode-7:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*then/g, "$1 then")
    if detailedDebug then console.log "beautifyCode-8:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*else/g, "$1 else")
    if detailedDebug then console.log "beautifyCode-9:\n" + code + " error: " + error
    code = code.replace(/;$/gm, "")
    if detailedDebug then console.log "beautifyCode-10:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*->/g, "$1 ->")
    if detailedDebug then console.log "beautifyCode-11:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*!=/g, "$1 !=")
    if detailedDebug then console.log "beautifyCode-12:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*>=/g, "$1 >=")
    if detailedDebug then console.log "beautifyCode-13:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*<=/g, "$1 <=")
    if detailedDebug then console.log "beautifyCode-14:\n" + code + " error: " + error
    code = code.replace(/([\w\d;\)])[\t ]*=/g, "$1 =")
    if detailedDebug then console.log "beautifyCode-15:\n" + code + " error: " + error
    code = code.replace(/\=([\w\d\(])/g, "= $1")
    if detailedDebug then console.log "beautifyCode-16:\n" + code + " error: " + error
    #code = code.replace(/\)([\t ]+\d)/g, ");$1")
    #if detailedDebug then console.log "beautifyCode-17:\n" + code + " error: " + error
    code = code.replace(/\)[\t ]*if/g, "); if")
    if detailedDebug then console.log "beautifyCode-18:\n" + code + " error: " + error
    code = code.replace(/,[\t ]*->/gm, ", ->")
    if detailedDebug then console.log "beautifyCode-18.5:\n" + code + " error: " + error
    code = code.replace(/;[\t ]+$/gm, "")
    if detailedDebug then console.log "beautifyCode-19:\n" + code + " error: " + error
    code = code.replace(/♠/g, "")
    if detailedDebug then console.log "beautifyCode-20:\n" + code + " error: " + error

    # transform stuff like (3).times and (n).times
    # into 3.times and n.times
    code = code.replace(/\(\s*(\d+|[$A-Z_][0-9A-Z_$]*)\s*\)\.times/gi, "$1.times")
    if detailedDebug then console.log "beautifyCode-21:\n" + code + " error: " + error

    code = code.replace(/\=[\t ]+-/g, "= -")
    if detailedDebug then console.log "beautifyCode-22:\n" + code + " error: " + error

    allFunctionsRegex = @allCommandsRegex + "|" + @expressionsRegex
    rx = RegExp("\\( *("+allFunctionsRegex+") *\\)",'g')
    code = code.replace(rx, "$1")
    if detailedDebug then console.log "beautifyCode-23:\n" + code + " error: " + error

    code = code.replace(/[ ]*then/g, " then")
    if detailedDebug then console.log "beautifyCode-24:\n" + code + " error: " + error


    return [code, error]


  # we receive the times command
  # in all sorts of ways. With binding, without
  # binding, with colons, with extra arrows,
  # with a dot before times...
  # here we normalise to the following forms:
  #   x times
  # or
  #   x times with var:

  normaliseTimesNotationFromInput:(code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # remove dot and extra arrow in case of
    # non-binding notation
    code = code.replace(/\.times([^\w\d])/gm, " times$1")
    code = code.replace(/(^[\t ]*|[\t ]+)times[\t .]*->/gm, "$1times ")

    # normalise the binding syntax
    code = code.replace(/(^[\t ]*|[\t ]+)times[\t .]*\([\t .]*([\w]*)[\t .]*\)[\t .]*->/gm, "$1times with $2:")

    # remove the arrow in the case of binding
    code = code.replace(/(^[\t ]*|[\t ]+)times[\t .]*with[\t .]*([\w]*)[\t .]*:?[\t .]*->/gm, "$1times with $2:")

    if detailedDebug then console.log "normaliseTimesNotationFromInput-1:\n" + code + " error: " + error

    return [code, error]


  checkBasicErrorsWithTimes:(code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # if what we transform makes any sense *at all*, then
    # coffeescript will translate it to js and run it, which
    # in some cases we don't want.
    # We want to simply rule out some common cases here
    # so we don't need to make the regexpes too complicated
    # For example we want to avoid:
    #
    #   peg; times rotate box 2* wave
    # to become
    #   (peg()).times ->  rotate box 2* wave()
    # or
    #   peg times rotate box 2* wave
    # to become
    #   peg.times ->  rotate box 2* wave()
    #
    # and run simply because we forgot a number in front
    # of 'times'

    rx = RegExp("("+@allCommandsRegex+")\\s+times(?![\\w\\d])",'g')

    if /^\s*times/gm.test(code) or
      /;\s*times/g.test(code) or
      /else\s+times/g.test(code) or
      /then\s+times/g.test(code) or
      rx.test(code)
        programHasBasicError = true
        return [undefined, "how many times?"]
    return [code, error]

  unbindFunctionsToArguments: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?
    # put back in place "sin⨁a,b" into "sin a,b" 
    code = code.replace(/⨁/g, "")
    return @normaliseCode(code, error)

  # in order to proper recognise where expressions
  # start and end, we need to tie the functions with their
  # arguments. For example "sin a" has to becomde
  # sin⨁ a.
  # The regexp for isolating expressions stops capturing
  # when there are two tokens not tied by an operator,
  # so this is why adding that special operator is needed
  bindFunctionsToArguments: (code, error, userDefinedFunctionsWithArguments) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # we don't want "sin times" to be considered an expression
    # so introduce a blocker character to avoid "sin times"
    # to becomde "sin⨁ times"
    rx = RegExp("([^\\w\\d\\r\\n])("+(@allCommandsRegex+"|times")+")(?![\w\d])",'g')
    code = code.replace(rx, "$1⧻$2")
    if detailedDebug then console.log "transformTimesSyntax-1\n" + code + " error: " + error


    # "expression" functions such as in "sin a,b" need to become
    # "sin⨁a,b" 
    # the for is needed for example for cases like round(pulse 15) times
    expsAndUserFunctionsWithArgs =  @expressionsRegex + userDefinedFunctionsWithArguments
    rx = RegExp("(^|[^\\w\\d\\r\\n])("+expsAndUserFunctionsWithArgs+")([ \\(]+)(?![⧻\\+\\-*/%,⨁])",'gm')
    for i in [0...5]
      code = code.replace(rx, "$1$2$3⨁")
      if detailedDebug then console.log "transformTimesSyntax-2\n" + code + " error: " + error

    # remove blocker character to avoid "sin times"
    # to becomde "sin⨁ times"
    code = code.replace(/⧻/g, "")

    return @normaliseCode(code, error)

  transformTimesSyntax: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?


    if detailedDebug then console.log "transformTimesSyntax-0\n" + code + " error: " + error
    #code = code.replace(/(else)\s+([a-zA-Z1-9])([^;\r\n]*) times[:]?([^a-zA-Z0-9])/g, "$1 ($2$3).times -> $4")
    #if detailedDebug then console.log "transformTimesSyntax-1\n" + code + " error: " + error
    #code = code.replace(/(then)\s+([a-zA-Z1-9])([^;\r\n]*) times[:]?([^a-zA-Z0-9])/g, "$1 ($2$3).times -> $4")
    #if detailedDebug then console.log "transformTimesSyntax-2\n" + code + " error: " + error
    # without the following, "if 2 times a" becomes "(if 2).times a"
    #code = code.replace(/(if)\s+([a-zA-Z1-9])([^;\r\n]*) times[:]?([^a-zA-Z0-9])/g, "$1 ($2$3).times -> $4")
    #if detailedDebug then console.log "transformTimesSyntax-3\n" + code + " error: " + error

    code = code.replace(/then/g, "then;")
    code = code.replace(/else/g, ";else;")

    # the diamond (♦) will be in front of the "times"
    # argument. This is needed to make it so
    # the qualifiers will be able to be fleshed out
    # correctly
    

    # simple mathematical expressions
    # e.g. rotate 2,a+1+3*(a*2.32+Math.PI) 2 times box
    code = code.replace(/(([\d\w\.\(\)]+([\t ]*[\+\-*\/⨁%,][\t ]*))+[\d\w\.\(\)]+|[\d\w\.\(\)]+) times[:]?(?![\w\d])/g, "♦ ($1).times ->")
    if detailedDebug then console.log "transformTimesSyntax-3\n" + code + " error: " + error

    # strip the out parens if there is one too many
    code = code.replace(/\(\((([\d\w\.\(\)]+([\t ]*[\+\-*\/⨁%,][\t ]*))+[\d\w\.\(\)]+|[\d\w\.\(\)]+)\)\)\.times /g, "($1).times ")
    if detailedDebug then console.log "transformTimesSyntax-3.2\n" + code + " error: " + error

    allFunctionsRegex = @allCommandsRegex + "|" + @expressionsRegex

    # ([\d\w\(\)]+([ ]*[-+/*][ ]*[\d\w\(\)]+(\.[\d\w\(\)]+)?)+)+ captures
    # simple mathematical expressions
    # e.g. rotate 2,a+1+3*(a*2.32+Math.PI) 2 times box
    rx = RegExp("("+allFunctionsRegex+")[\\t ]*;[; ]*\\(?(([\\d\\w\\.\\(\\)]+([\\t ]*[\\+\\-*/⨁%,][\\t ]*))+[\\d\\w\\.\\(\\)]+|[\\d\\w\\.\\(\\)]+)\\)\\.times ->",'g')
    code = code.replace(rx, "$1()♦ ($2).times ->")
    if detailedDebug then console.log "transformTimesSyntax-3.5\n" + code + " error: " + error

    # whatever is remaining should be turned into a normal form with semicolon before it.
    code = code.replace(/\((([\d\w\.\(\)]+([\t ]*[\+\-*\/⨁%,][\t ]*))+[\d\w\.\(\)]+|[\d\w\.\(\)]+)\)[ \.]*times[\\t ]*[:]?[\\t ]*(?![\w\d])/g, ";($1).times ")
    if detailedDebug then console.log "transformTimesSyntax-3.55\n" + code + " error: " + error

    # whatever is remaining should be turned into a normal form with semicolon before it.
    code = code.replace(/[ ](([\d\w\.\(\)]+([\t ]*[\+\-*\/⨁%,][\t ]*))+[\d\w\.\(\)]+|[\d\w\.\(\)]+)\.times[\t ]*[:]?[\t ]*(?![\w\d])/g, "; $1.times ")
    if detailedDebug then console.log "transformTimesSyntax-3.56\n" + code + " error: " + error

    # transformation above transforms ;(sin ⨁ 5).times  ->  into ;(sin ⨁; 5).times   ->
    # so fixing that
    code = code.replace(/⨁;/g, "")


    # repairs myFunc = -> ; 20.times -> rotate -> box()
    code = code.replace(/->[\t ]*[♦;\t ]*[\t ]*\(/g, "-> (")
    if detailedDebug then console.log "transformTimesSyntax-3.57\n" + code + " error: " + error

    code = code.replace(/then[\t ]*[♦;\t ]*[\t ]*\(/g, "then (")
    if detailedDebug then console.log "transformTimesSyntax-3.57\n" + code + " error: " + error

    # the transformation above generates stuff like
    #   peg(); ;  (2).times ->
    # and
    #   ; (1+1).times ->...
    # so fixing these cases
    # but careful not to destroy the indentations
    code = code.replace(/->\s*;/g, "->")
    if detailedDebug then console.log "transformTimesSyntax-3.6\n" + code + " error: " + error
    code = code.replace(/([\w\d;])[\t ]?;[; ]+\(/g, "$1; (")
    if detailedDebug then console.log "transformTimesSyntax-3.7\n" + code + " error: " + error
    code = code.replace(/\)[ ]*;[; ]+\(/g, "); (")
    if detailedDebug then console.log "transformTimesSyntax-3.75\n" + code + " error: " + error
    code = code.replace(/^([\t ]*);[; ]+\(/gm, "$1(")
    if detailedDebug then console.log "transformTimesSyntax-3.8\n" + code + " error: " + error
    code = code.replace(/^([\t ]*)[♦;][;♦ ]*/gm, "$1")
    if detailedDebug then console.log "transformTimesSyntax-3.9\n" + code + " error: " + error
    
    # It's unclear whether the cases catered by the two 
    # transformatione below ever make sense.
    # without the following, "a = (2 times box)" becomes "(a = 2.times -> box())"
    code = code.replace(/(\()\s*([\w\d])([^;\r\n]*) times[:]?([^\w\d])/g, "$1 ($2$3).times -> $4")
    if detailedDebug then console.log "transformTimesSyntax-4\n" + code + " error: " + error
    # without the following, "a = 2 times box" becomes "(a = 2).times -> box()"
    code = code.replace(/(=)\s*([\w\d])([^;\r\n]*) times[:]?([^\w\d])/g, "$1 ($2$3).times -> $4")
    if detailedDebug then console.log "transformTimesSyntax-4\n" + code + " error: " + error

    # the [^;\r\n]*? is to make sure that we don't take ; within the times argument
    # example:
    #  box; box ;  2 times: peg
    # if we don't exclude the semicolon form the times argument then we transform into
    #  box; (box ;  2).times ->  peg
    # which is not correct
    code = code.replace(/;[ \t]*([\w\d])([^;\r\n]*?) times[:]?([^\w\d])/g, "♦ ($1$2).times -> $3")
    if detailedDebug then console.log "transformTimesSyntax-5\n" + code + " error: " + error

    # the transformation above generates stuff like
    #   if true then; (2).times ->
    # so fixing that
    code = code.replace(/if\s*;/g, "if")
    code = code.replace(/then\s*;/g, "then")
    code = code.replace(/else\s*;/g, "else")
    if detailedDebug then console.log "transformTimesSyntax-5.5\n" + code + " error: " + error


    # takes care of cases like myFunc = -> 20 times rotate box
    code = code.replace(/(->)\s+([\w\d])(.*?) times[:]?([^\w\d])/g, "$1 ($2$3).times -> $4")
    if detailedDebug then console.log "transformTimesSyntax-6\n" + code + " error: " + error


    # last (catch all other cases where it captures everything
    # since the start of the line,
    # which is why you need to handle the other cases before):
    # the ^; is to avoid this matching:
    #   peg; times rotate box 2* wave (group1: p group2: eg; group3: rot...wave)
    code = code.replace(/([\w\d])(.*?) times[:]?([^\w\d])/g, "($1$2).times -> $3")
    if detailedDebug then console.log "transformTimesSyntax-7\n" + code + " error: " + error

    code = code.replace(/;+[\t ]*else/g, " else")
    if detailedDebug then console.log "transformTimesSyntax-8\n" + code + " error: " + error

    code = code.replace(/^(\t*) else/gm, "$1else")
    if detailedDebug then console.log "transformTimesSyntax-9\n" + code + " error: " + error

    return @normaliseCode(code, error)

  # transforms the case where we are binding a variable
  # e.g.
  #   3 times with i box i
  # first bring to intermediate form
  #   3.timesWithVariable -> (i) -> box i
  # then just to 
  #   3.times (i) -> box i
  # which is then handled correctly by
  # coffeescript
  # note that the parentheses around the i
  # are needed!
  #   3.times i -> box i
  # is transformed by coffeescript in something
  # that doesn't make sense.

  transformTimesWithVariableSyntax: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # first to intermediate form

    code = code.replace(/\.times[\t ]*with[\t ]*(\w+)[\t ]*(:|;|,[\t ]*->)?/g, ".timesWithVariable -> ($1) $2")

    if detailedDebug then console.log "transformTimesWithVariableSyntax-1\n" + code + " error: " + error

    code = code.replace(/\.times[\t ]*->[\t ]*with[\t ]*(\w+)[\t ]*(:|;|,[\t ]*->)?/g, ".timesWithVariable -> ($1) ->")

    if detailedDebug then console.log "transformTimesWithVariableSyntax-2\n" + code + " error: " + error

    # now from intermediate form to the form with just "times"

    #code = code.replace(/\.timesWithVariable[\t ]*->[\t ]*/g, ".times ")
    code = code.replace(/\.timesWithVariable[\t ]*->[\t ]*/g, ".timesWithVariable ")

    if detailedDebug then console.log "transformTimesWithVariableSyntax-3\n" + code + " error: " + error

    return @normaliseCode(code, error)

  # the need for "parametersForBracketedFunctions" is so that
  # code such as
  #    a = <fill red>
  #    b= <box>
  #    a b
  # can work. Basically the function inside a needs to
  # be able to accept further functions to be chained.

  adjustFunctionalReferences: (code, error, userDefinedFunctions, bracketsVariables) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # this one is so that arrow is not mistaken
    # for a closed bracket
    code = code.replace(/->/g, "→")

    # turns things like
    #  either <rotate -> box>, <peg>
    #  either <box 2>, <peg 2>
    # into
    #  either (-> rotate -> box), (->peg)
    #  either (-> box 2), (->peg 2)
    expressionsAndUserDefinedFunctionsRegex = @expressionsRegex + userDefinedFunctions + bracketsVariables
    allFunctionsRegex = @allCommandsRegex + "|" + expressionsAndUserDefinedFunctionsRegex

    rx = RegExp("<[\\s]*(("+allFunctionsRegex+")[\\t ]*)>",'gm')
    code = code.replace(rx, "($1♠)")

    rx = RegExp("<[\\s]*(("+allFunctionsRegex+")[^\\r\\n]*?)>",'gm')
    code = code.replace(rx, "((parametersForBracketedFunctions)->($1, -> (if parametersForBracketedFunctions? then parametersForBracketedFunctions() else nil)))")

    code = code.replace(/→/g, "->")

    if detailedDebug then console.log "adjustFunctionalReferences-1\n" + code + " error: " + error

    return [code, error]



  fixParamPassingInBracketedFunctions: (code, error, userDefinedFunctions) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace(/\(\),? -> \(if parametersForBracketedFunctions/g, " -> (if parametersForBracketedFunctions")

    if detailedDebug then console.log "fixParamPassingInBracketedFunctions-1\n" + code + " error: " + error

    return [code, error]

  adjustImplicitCalls: (code, error, userDefinedFunctions, userDefinedFunctionsWithArguments, bracketsVariables) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    expressionsAndUserDefinedFunctionsRegex = @expressionsRegex + userDefinedFunctions + bracketsVariables
    allFunctionsRegex = @allCommandsRegex + "|" + expressionsAndUserDefinedFunctionsRegex + bracketsVariables

    
    # adding () to single tokens on their own at the start of a line
    # ball
    if detailedDebug then console.log "adjustImplicitCalls-1\n" + code + " error: " + error
    rx = RegExp("^([ \\t]*)("+allFunctionsRegex+")[ ]*$",'gm')
    code = code.replace(rx, "$1$2();")
    if detailedDebug then console.log "adjustImplicitCalls-2\n" + code + " error: " + error


    # adding () to single tokens at the start of the line
    # followed by a semicolon (might be followed by more instructions)
    # ball;
    # ball; somethingelse
    rx = RegExp("^([ \\t]*)("+allFunctionsRegex+")[ ]*;",'gm')
    code = code.replace(rx, "$1$2();")
    if detailedDebug then console.log "adjustImplicitCalls-3\n" + code + " error: " + error

    # adding () to any functions not at the beginning of a line
    # and followed by a anything that might end the command
    # eg semicolon, closing parenthesis, math sign, etc.
    #   something;ball
    #   something;ball;
    #   something;ball;ball
    #   something;ball;ball;
    #   ✓doOnce ball; background red
    #   if ball then ball else something
    #   box wave
    #   box wave(wave)
    # Why do we handle Commands differently from expressions?
    # cause they have different delimiters
    # I expect
    #   wave -1
    # to be transformed into
    #   wave() -1
    # but I don't want
    #   box -1
    # to turn into box() -1
    delimitersForCommands = ":|;|\\,|\\?|\\)|//|\\#|\\s+if|\\s+else|\\s+then"
    # note how + and - need a space afterwards. This is because
    # "wave +1" is different from "wave + 1" (and same with -)
    delimitersForExpressionsWithSpaces = delimitersForCommands + "|" + "\\+[\\s|;]|-[\\s|;]|\\*|/|%|&|]|<|>|==|!=|>=|<=|!(?![=])|\\s+and\\s+|\\s+or\\s+|\\s+not\\s+|\\|"

    # [todo] you should ideally derive this coming regexp
    # from the one above
    delimitersForExpressionsWithoutSpaces = delimitersForCommands + "|" + "\\+|-|\\*|/|%|&|]|<|>|==|!=|>=|<=|!(?![=])|\\s+and\\s+|\\s+or\\s+|\\s+not\\s+|\\|"

    #we don't want the dash of the arrow to count as a minus, so
    #replacing the arrow with one char
    code = code.replace(/->/g, "→")

    if detailedDebug then console.log "adjustImplicitCalls-4 brackets vars:" + bracketsVariables
    rx = RegExp("([^\\w\\d\\r\\n])("+@allCommandsRegex+bracketsVariables+")[ \\t]*("+delimitersForCommands+")",'g')
    for i in [1..2]
      code = code.replace(rx, "$1$2()$3")
    if detailedDebug then console.log "adjustImplicitCalls-4\n" + code + " error: " + error

    rx = RegExp("([^\\w\\d\\r\\n])("+expressionsAndUserDefinedFunctionsRegex+")([ \\t]*)("+delimitersForExpressionsWithSpaces+")",'g')
    if detailedDebug then console.log rx
    for i in [1..2]
      code = code.replace(rx, "$1$2()$3$4")
    if detailedDebug then console.log "adjustImplicitCalls-5\n" + code + " error: " + error

    # handles case of tightly-packed keywords such as in
    # a = wave+wave+wave
    rx = RegExp("([^\\w\\d\\r\\n])("+expressionsAndUserDefinedFunctionsRegex+")("+delimitersForExpressionsWithoutSpaces+")",'g')
    if detailedDebug then console.log rx
    for i in [1..2]
      code = code.replace(rx, "$1$2()$3")
    if detailedDebug then console.log "adjustImplicitCalls-5.5\n" + code + " error: " + error


    #box 0.5,2
    #box; rotate; box
    #if random() > 0.5 then box 0.2,3; ball; background red
    #if ball then ball if true then 0 else 1
    #ball if true then 0 else 1
    
    # tokens at the end of the line (without final semicolon,
    # if there is a final semicolon it's handled by previous case)
    # doOnce frame = 0; box
    # if random() > 0.5 then box
    # 2 times -> box
    # 2 times -> rotate; box
    rx = RegExp("([^\\w\\d\\r\\n])("+allFunctionsRegex+")[ \\t]*$",'gm')
    code = code.replace(rx, "$1$2()")

    code = code.replace(/→/g, "->")

    if detailedDebug then console.log "adjustImplicitCalls-7\n" + code + " error: " + error
    return [code, error]

  addCommandsSeparations: (code, error, userDefinedFunctions) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    expressionsAndUserDefinedFunctionsRegex = @expressionsRegex + userDefinedFunctions
    allFunctionsRegex = @allCommandsRegex + "|" + expressionsAndUserDefinedFunctionsRegex
    
    rx = RegExp("("+@allCommandsRegex+")([ \\t]*)("+@allCommandsRegex+")([ ]*)($)?",'gm')
    code = code.replace(rx, "$1();$2$3$4$5")
    if detailedDebug then console.log "addCommandsSeparations 1: " + code

    return [code, error]

  # Qualifiers are special keywords that make
  # it easy to change qualities of some
  # primitives without affecting the
  # primitives that come afterwards.
  findQualifiers: (code, error, bracketsVariables) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # this is to avoid transformations to span
    # the else, since all transformations stop
    # at semicolon. This is transformed back
    # at the end of the method.
    code = code.replace(/([^\w\d;])then(?![\w\d])/g, "$1;then")
    code = code.replace(/([^\w\d;])else(?![\w\d])/g, "$1;else")

    # we don't want the qualifiers
    # to span across ">, <" in this case:
    #   either <box 2>, <peg 2>
    # otherwise box would become a qualifier
    # and cause
    #   either <box 2>, < ->peg 2>
    code = code.replace(/\s*>\s*,/g, "♠")

    # already transformer stuff like
    #    rotate (-> box())
    # can't be transformed again, so
    # making sure that the qualifiers can't span
    # a function definition

    primitivesAndMatrixAndDiamondRegex = @primitivesAndMatrixRegex + bracketsVariables + '|♦'

    previousCodeTransformations = ''
    code = code.replace(/->/g, "→")
    while code != previousCodeTransformations
      previousCodeTransformations = code

      rx = RegExp("(^|[^\\w\\d\\r\\n])("+@primitivesAndMatrixRegex+bracketsVariables+")(?![\\w\\d\\(])([^\\r\\n;'♠→]*?)("+primitivesAndMatrixAndDiamondRegex+")([^\\w\\d\\r\\n]*)",'gm')
      replacement = '$1$2ing❤QUALIFIER$3$4$5'
      code = code.replace(rx,replacement)

    code = code.replace(/→/g, "->")
    code = code.replace(/♠/g, ">,")

    if detailedDebug then console.log "findQualifiers 4: " + code

    return [code, error]

  fleshOutQualifiers: (code, error, bracketsVariables, bracketsVariablesArray) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?


    # we need to consider things like rotateQUALIFIER
    # as a keyword beause we want
    #   rotateQUALIFIER rotateQUALIFIER box
    # to first expand the first rotateQUALIFIER into
    #   rotate (→ rotateQUALIFIER box)
    # and not,
    #   rotate rotateQUALIFIER (→ box)
    # similar reason for adding rotate
    primtvsAndQualsRegex = ''
    for i in [0...@qualifyingCommands.length]
      primtvsAndQualsRegex = primtvsAndQualsRegex + @qualifyingCommands[i] + '|' + @qualifyingCommands[i]+"ing❤QUALIFIER|"
    for i in [0...@primitives.length]
      primtvsAndQualsRegex = primtvsAndQualsRegex + @primitives[i] + '|' + @primitives[i]+"ing❤QUALIFIER|"
    for i in [0...bracketsVariablesArray.length]
      primtvsAndQualsRegex = primtvsAndQualsRegex + bracketsVariablesArray[i] + '|' + bracketsVariablesArray[i]+"ing❤QUALIFIER|"


    primtvsAndQualsRegex = primtvsAndQualsRegex + '♦'

    previousCodeTransformations = ''

    # the (→ $4$5); is to make sure that
    #   rotate line;  rotate  box
    # becomes
    #   rotate (-> line());  rotate  (-> box())
    # instead of
    #   rotate -> line();  rotate -> box()
    # i.e. there is no chaining across semicolon

    while code != previousCodeTransformations
      previousCodeTransformations = code

      if detailedDebug then console.log "fleshOutQualifiers 0: @primitivesAndMatrixRegex: " + @primitivesAndMatrixRegex + " bracketsVariables: " + bracketsVariables + " primtvsAndQualsRegex: " + primtvsAndQualsRegex

      rx = RegExp("(^|[^\\w\\d\\r\\n])(("+@primitivesAndMatrixRegex+bracketsVariables+")ing❤QUALIFIER)(?![\\w\\d\\(])([^\\r\\n;→]*?)("+primtvsAndQualsRegex+")([^;\\r\\n]*)(.*)",'gm')
      replacement = '$1$3$4→ $5$6;$7'
      code = code.replace(rx,replacement)
      if detailedDebug then console.log "fleshOutQualifiers 1: " + code

      rx = RegExp("(^|[^\\w\\d\\r\\n])(("+@primitivesAndMatrixRegex+bracketsVariables+")ing❤QUALIFIER)(?![\\w\\d\\(])([^\\r\\n;→♦❤]*?)♦",'g')
      replacement = '$1$3$4 →'
      code = code.replace(rx,replacement)

      if detailedDebug then console.log "fleshOutQualifiers 2: " + code

    # the trasformations above creates
    # stuff like:
    #    run <→ box> 2;
    # so fixing that
    code = code.replace(/<→/g, "→ <")

    # we don't need the diamond anymore
    code = code.replace(/♦[♦\t ]*/g, "; ")

    code = code.replace(/;+[\t ]*else/gm, " else")
    code = code.replace(/^(\t*) else/gm, "$1else")

    # the trasformations above add lots of redundant
    # semicolons and spaces like so:
    #    ...tate (-> rotate (-> box())))))))))); ;  ;   
    # so fixing that
    code = code.replace(/\);([; ]*)/g, "); ")

    # these two are to satisfy idempotency
    code = code.replace(/->\s*→/g, "->")
    code = code.replace(/→\s*->/g, "->")
    if detailedDebug then console.log "fleshOutQualifiers 7: " + code

    rx = RegExp("(^|[^\\w\\d\\r\\n])("+@primitivesAndMatrixRegex+bracketsVariables+")(?![\\w\\d\\(])(\\s*\\(?→)",'gm')
    replacement = '$1$2 ->'
    code = code.replace(rx,replacement)
    if detailedDebug then console.log "fleshOutQualifiers 9: " + code
    
    # replace all the → that *do* need to be prepended
    # with a comma
    code = code.replace(/([^,])\s+([\(]?)→/g, "$1, $2->")
    if detailedDebug then console.log "fleshOutQualifiers 10: " + code

    # replace all the remaining arrows
    code = code.replace(/→/g, "->")
    if detailedDebug then console.log "fleshOutQualifiers 11: " + code

    code = code.replace(/;+[\t ]*else/g, " else")
    code = code.replace(/^(\t*) else/gm, "$1else")
    code = code.replace(/;*[\t ]*then/g, " then")

    return [code, error]

  wasFunctionNameAlreadyFound: (str, strArray) ->
    j = 0
    while j < strArray.length
      if strArray[j].match(str) then return true
      j++
    false

  # what we are trying to do here is to figure
  # out which other keywords besides the LCL ones
  # we need to automatically invoke as functions.
  # Findind user functions is an ill-posed problem
  # because the same variable might be a function
  # in one place and a number in another. And yet
  # once we find that there is a function definition
  # with that name *anywhere* in the code, for us
  # it's a function everywhere, so we force the
  # function call. Note that this can
  # be mitigated by wrapping the supposed user
  # functions with a special function that invokes
  # the supposed user function if it actually is
  # a function, or otherwise returns
  # the content of the variable if it is not a function.
  # That way we would always make the right thing,
  # although at some sort of performance penalty.
  #
  # Also we keep a separate list of names of functions
  # that need a parameter. This is because expressions
  # containing these functions consume an argument,
  # so we need to be aware of that to correctly
  # consume the argument, as for example
  # "myFunc a" is an expression even though there
  # is no operator between the two tokens.
  # also in automatic parentheses explicitation,
  # stuff like "myFunc() a" should actually be
  # "myFunc a".

  findUserDefinedFunctions: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    userDefinedFunctions = []
    userDefinedFunctionsWithArguments = []

    # form a = -> ...
    rx = RegExp("([a-zA-Z\\d]+)([ \\t]*)=[ \\t]*->",'gm')
    while match = rx.exec code
      userDefinedFunctions.push(match[1])
    if detailedDebug then console.log "findUserDefinedFunctions-1\n" + code + " error: " + error

    # form a = () -> ...
    rx = RegExp("([a-zA-Z\\d]+)([ \\t]*)=[ \\t]*\\([ \\t]*\\)[ \\t]*->",'gm')
    while match = rx.exec code
      userDefinedFunctions.push(match[1])
    if detailedDebug then console.log "findUserDefinedFunctions-2\n" + code + " error: " + error

    # all other forms. Finds all forms so just check whether
    # we didn't get this function name already
    rx = RegExp("([a-zA-Z\\d]+)([ \\t]*)=[ \\t]*[\\(-]([^>\\r\\n]*)>",'gm')
    while match = rx.exec code
      functionName = match[1]
      if not @wasFunctionNameAlreadyFound functionName, userDefinedFunctions
        userDefinedFunctions.push(functionName)
        userDefinedFunctionsWithArguments.push(functionName)
    if detailedDebug then console.log "findUserDefinedFunctions-3\n" + code + " error: " + error

    userDefinedFunctions = userDefinedFunctions.join "|"
    if userDefinedFunctions != ""
      userDefinedFunctions = "|"+userDefinedFunctions

    userDefinedFunctionsWithArguments = userDefinedFunctionsWithArguments.join "|"
    if userDefinedFunctionsWithArguments != ""
      userDefinedFunctionsWithArguments = "|"+userDefinedFunctionsWithArguments

    #console.log "*****" + userDefinedFunctions
    return [code, error, userDefinedFunctions, userDefinedFunctionsWithArguments]

  findBracketVariables: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    bracketsVariablesArray = []

    # form a = <...
    rx = RegExp("([a-zA-Z\\d]+)([ \\t]*)=[ \\t]*<",'gm')
    while match = rx.exec code
      bracketsVariablesArray.push(match[1])
      #@primitives.push(match[1])
      if detailedDebug then console.log "findbracketsVariables-1 pushing " + match[1]
    if detailedDebug then console.log "findbracketsVariables-2\n" + code + " error: " + error


    bracketsVariables = bracketsVariablesArray.join "|"
    if bracketsVariables != ""
      bracketsVariables = "|"+bracketsVariables

    if detailedDebug then console.log "bracketsVariables: >" + bracketsVariables + "<"

    rx = RegExp("([a-zA-Z\\d]+)([ \\t]*)=[ \\t]*<",'gm')
    code = code.replace(rx, "BRACKETVAR$1BRACKETVAR = <")
    if detailedDebug then console.log "findbracketsVariables-3\n" + code + " error: " + error

    return [code, error, bracketsVariables, bracketsVariablesArray]

  putBackBracketVarOriginalName: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?


    rx = RegExp("BRACKETVAR([a-zA-Z\\d]+)BRACKETVAR",'gm')
    code = code.replace(rx, "$1")
    if detailedDebug then console.log "putBackBracketVarOriginalName-1\n" + code + " error: " + error

    return [code, error]

  # see the numbertimes file for more info on why this is needed
  addScopeToTimes: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # --- this is for idempotency
    rx = RegExp("\.times -> @, ->",'gm')
    code = code.replace(rx, ".times ->")
    if detailedDebug then console.log "addScopeToTimes-3\n" + code + " error: " + error

    rx = RegExp("\.times -> @,",'gm')
    code = code.replace(rx, ".times ->")
    if detailedDebug then console.log "addScopeToTimes-3\n" + code + " error: " + error
    # ---------------------


    rx = RegExp("\.times ",'gm')
    code = code.replace(rx, ".times @, ")
    if detailedDebug then console.log "addScopeToTimes-1\n" + code + " error: " + error


    # --- this is for idempotency
    rx = RegExp("\.timesWithVariable @, ",'gm')
    code = code.replace(rx, ".timesWithVariable ")
    if detailedDebug then console.log "addScopeToTimes-3\n" + code + " error: " + error
    # ---------------------

    rx = RegExp("\.timesWithVariable ",'gm')
    code = code.replace(rx, ".timesWithVariable @, ")
    if detailedDebug then console.log "addScopeToTimes-4\n" + code + " error: " + error

    return [code, error]

  evaluateAllExpressions: (code, error, userDefinedFunctions) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    expressionsAndUserDefinedFunctionsRegex = @expressionsRegex + userDefinedFunctions
    allFunctionsRegex = @allCommandsRegex + "|" + expressionsAndUserDefinedFunctionsRegex

    rx = RegExp("("+expressionsAndUserDefinedFunctionsRegex+")([ \\t]*)times",'g')
    code = code.replace(rx, "$1()$2times")
    
    rx = RegExp("([^;>\\( \\t\\r\\n])([ ])("+@allCommandsRegex+")([^\\w\\d\\r\\n])",'gm')
    code = code.replace(rx, "$1;$2$3$4")
    if detailedDebug then console.log "evaluateAllExpressions-1\n" + code + " error: " + error

    # the transformation above can add a semicolon
    # after an else, fixing that
    code = code.replace(/else;/g, "else")

    rx = RegExp("([^\\w\\d\\r\\n])("+allFunctionsRegex+")([ \\t]*);",'g')
    code = code.replace(rx, "$1$2();")
    if detailedDebug then console.log "evaluateAllExpressions-2\n" + code + " error: " + error
    rx = RegExp("([^\\w\\d\\r\\n])("+allFunctionsRegex+")([ \\t]*)$",'gm')
    code = code.replace(rx, "$1$2();")
    if detailedDebug then console.log "evaluateAllExpressions-3\n" + code + " error: " + error


    delimitersForCommandsMod = ":|;|\\,|\\?|//|\\#|\\selse|\\sthen"
    delimitersForExpressions = delimitersForCommandsMod + "|if|" + "\\+|-|\\*|/|%|&|]|<|>|=|\\|"
    delimitersForExpressions = delimitersForExpressions + userDefinedFunctions
    rx = RegExp("("+delimitersForExpressions+")([ \\t]*);",'g')
    code = code.replace(rx, "$1$2")
    if detailedDebug then console.log "evaluateAllExpressions-4\n" + code + " error: " + error

    #rx = RegExp("([^a-zA-Z0-9;>\\(])([ \\t]*)("+@allCommandsRegex+")([^a-zA-Z0-9])",'g')
    #code = code.replace(rx, "$1;$2$3$4")
    #code = code.replace(/[>][ ]*;/g, "> ")
    #code = code.replace(/[=][ ]*;/g, "= ")

    return @normaliseCode(code, error)


  adjustDoubleSlashSyntaxForComments: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # allows // for comments
    # the hash is more difficult to write
    code = code.replace(/\/\//g, "#")
    return [code, error]


  # The specs proposed to have the double
  # chevrons so to make the user
  # life easier separating the
  # commands.
  # I suspect there is no need for them
  # so this function removes them
  removeDoubleChevrons: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace(/>>/g, " ")
    return [code, error]

  ###
  Errors cases, subdivided by number of colors involved

  --- 0 colors
  stroke stroke -> redundant stroke
  fill fill -> redundant fill

  --- 1 color
  stroke color1 stroke -> redundant stroke
  fill color1 fill -> redundant fill
  noColor fill color stroke noColor -> missing color

  ---2 colors
  noFill/Stroke color color noFill/Stroke -> redundant color
  fill color color noFill/Stroke -> redundant color
  noFill/Stroke color color fill -> redundant color
  noFill/Stroke color fill colour noFill/Stroke

  ----3 colors
  color stroke/fill color color
  color color stroke/fill color
  color color color
  ###

  rearrangeColorCommands: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    # --- 0 colors error cases
    if /(^[\\t ]*|[^\w\d\r\n])stroke[\t ]+stroke([^\w\d\r\n]|$)/gm.test code
      return [undefined, "redundant stroke"]
    if /(^[\\t ]*|[^\w\d\r\n])fill[\t ]+fill([^\w\d\r\n]|$)/gm.test code
      return [undefined, "redundant fill"]


    rx = RegExp("(^[\\t ]*|;| )([\\t ]*)("+@colorsRegex+")(?![\\w\\d])",'gm')
    code = code.replace(rx, "$1$2♦$3♦")
    if detailedDebug then console.log "rearrangeColorCommands-1\n" + code + " error: " + error

    # --- 1 color error cases
    rx = RegExp("(^[\\t ]*|[^\\w\\d\\r\\n])stroke[\\t ]+♦([^♦]*)♦[\\t ]+stroke([^\\w\\d\\r\\n]|$)",'gm')
    if rx.test code
      return [undefined, "redundant stroke"]

    rx = RegExp("(^[\\t ]*|[^\\w\\d\\r\\n])fill[\\t ]+♦([^♦]*)♦[\\t ]+fill([^\\w\\d\\r\\n]|$)",'gm')
    if rx.test code
      return [undefined, "redundant fill"]

    # --- 2 color error cases
    rx = RegExp("(^[\\t ]*| )♦([^♦]*)♦[\\t ]+("+@colorsCommandsRegex+")[\\t ]+♦([^♦]*)♦[\\t ]+♦([^♦]*)♦([^\\w\\d\\r\\n]|$)",'gm')
    if rx.test code
      return [undefined, "redundant color"]

    rx = RegExp("(^[\\t ]*| )♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+("+@colorsCommandsRegex+")[\\t ]+♦([^♦]*)♦([^\\w\\d\\r\\n]|$)",'gm')
    if rx.test code
      return [undefined, "redundant color"]

    rx = RegExp("(^[\\t ]*| )♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+♦([^♦]*)♦( |$)",'gm')
    if rx.test code
      return [undefined, "redundant color"]

    rx = RegExp("(^[\\t ]*|[^♦\\r\\n][\\t ]+)("+@colorsCommandsRegex+")[\\t ]+♦([^♦]*)♦[\\t ]+("+@colorsCommandsRegex+")[\\t ]+([^♦\\r\\n]|$)",'gm')
    if rx.test code
      return [undefined, "missing color"]

    rx = RegExp("(^|;| )([\\t ]*)("+@colorsCommandsRegex+")(?![\\w\\d])",'gm')
    code = code.replace(rx, "$1$2♠$3♠")
    if detailedDebug then console.log "rearrangeColorCommands-2\n" + code + " error: " + error

    #rx = RegExp("(^[\\t ]*|[^♠\\r\\n][\\t ]+)♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+([^♦♠\\r\\n]|$)",'gm')
    #if rx.test code
    #  if detailedDebug then console.log "missing color command - 1"
    #  return [undefined, "missing color command"]

    # fill red red box
    # stroke red red box
    #rx = RegExp("(^[\\t ]*|[^♦\\r\\n][\\t ]+)♠("+@colorsCommandsRegex+")♠[\\t ]+♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+([^♠\\r\\n]|$)",'gm')
    #if rx.test code
    #  return [undefined, "redundant color"]

    # stroke green red box
    # fill red red box which is kind of silly
    rx = RegExp("(^[\\t ]*|[^♦\\r\\n][\\t ]+)♠("+@colorsCommandsRegex+")♠[\\t ]+♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+([^♠\\r\\n]*|$)",'gm')
    code = code.replace(rx, "$1♠$2♠ ♦$3♦ fill ♦$4♦ $5")
    if detailedDebug then console.log "rearrangeColorCommands-2.5\n" + code + " error: " + error

    #rx = RegExp("(^[\\t ]*|[^♠\\r\\n][\\t ]+)♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+♠("+@colorsCommandsRegex+")♠(?![\\w\\d])",'gm')
    #if rx.test code
    #  if detailedDebug then console.log "missing color command - 2"
    #  return [undefined, "missing color command"]

    rx = RegExp("(^[\\t ]*|[^♠\\r\\n][\\t ]+)♦([^♦]*)♦[\\t ]+♠("+@colorsCommandsRegex+")♠[\\t ]+♦([^♦]*)♦[\\t ]+([^♠\\r\\n]|$)",'gm')
    if rx.test code
      if detailedDebug then console.log "missing color command - 3"
      return [undefined, "missing color command"]

    # to avoid stuff like
    # box red red box
    rx = RegExp("(^[\\t ]*|[^♠\\r\\n][\\t ]+)♦([^♦]*)♦[\\t ]+♦([^♦]*)♦[\\t ]+([^♠\\r\\n]|$)",'gm')
    if rx.test code
      if detailedDebug then console.log "redundant color"
      return [undefined, "redundant color"]

    # 0.5)
    # color on its own in a line -> fill color
    rx = RegExp("^([\\t ]*)♦([^♦]*)♦([ \\t]*)$",'gm')
    code = code.replace(rx, "$1♠fill♠ ♦$2♦ $3")
    if detailedDebug then console.log "rearrangeColorCommands-3\n" + code + " error: " + error

    # 0.5)
    # noFill/noStroke/noColor color noFill/noStroke/noColor -> fill color
    rx = RegExp("(^[\\t ]*|; |([\\w\\d] *))♦([^♦]*)♦[ \\t]+([^♠\\r\\n])",'gm')
    code = code.replace(rx, "$1♠fill♠ ♦$3♦ $4")
    if detailedDebug then console.log "rearrangeColorCommands-3\n" + code + " error: " + error

    
    # 1)
    # color1,exp color2 stroke/fill nocolor -> color1,exp stroke/fill color2 nocolor
    rx = RegExp("([\\t ]*)♦([^♦]*)♦[\\t ]+([,][\\t ]*)(([\\d\\w\\.\\(\\),]+([\\t ]*[\\+\\-*\\/⨁%,][\\t ]*))+[\\d\\w\\.\\(\\)]+|[\\d\\w\\.\\(\\)]+)*[\\t ]+♦([^♦]*)♦[\\t ]+♠("+@colorsCommandsRegex+")♠[\\t ]+(?!♦)",'gm')
    code = code.replace(rx, "$1♦$2♦$3$4 ♠$7♠ ♦$6♦")
    if detailedDebug then console.log "rearrangeColorCommands-4\n" + code + " error: " + error




    # 2)
    # noFill/noStroke color stroke/fill nocolor -> stroke/fill colour
    rx = RegExp("(^[\\t ]*|[^♠\\r\\n][\\t ]*)♦([^♦]*)♦[\\t ]*♠("+@colorsCommandsRegex+")♠([\\t ]+(?!♦)|$)",'gm')
    code = code.replace(rx, "$1♠$3♠ ♦$2♦ $4")
    if detailedDebug then console.log "rearrangeColorCommands-5\n" + code + " error: " + error

    # 2)
    # noFill/noStroke color stroke/fill1 stroke/fill2 -> stroke/fill1 colour stroke/fill2
    rx = RegExp("(^[\\t ]*|[^♠\\r\\n][\\t ]*)♦([^♦]*)♦[\\t ]*♠("+@colorsCommandsRegex+")♠[\\t ]*♠",'gm')
    code = code.replace(rx, "$1♠$3♠ ♦$2♦ ")
    if detailedDebug then console.log "rearrangeColorCommands-6\n" + code + " error: " + error

    code = code.replace(/[♠♦]/g, "")

    return [code, error]

  # the last argument of any qualifier, if it's
  # a function call, might capture the following
  # function chaining, like so:
  #   a = (val) -> val * 2
  #   rotate 3, a 1 box 3, 4, a 1
  # might become, incorrectly:
  #   a = (val) -> val * 2
  #   rotate 3, a(1, -> box 3, 4, a 1)
  #
  # handles the following examples
  #   a = (val) -> val * 2
  #   rotate 3, a 1 box 3, 4, a 1
  # so it's translated in
  #   a = (val) -> val * 2
  #   rotate 3, (a 1), -> box 3, 4, a 1 
  # same for
  #   rotate 3, wave wave 2 box 3, 4
  # ...turned into
  #   rotate 3, wave(wave(2)), -> box 3, 4
  # and also
  #   rotate 3, wave pulse / 10 box 3, 4
  # ...turned into
  #   rotate 3, wave(pulse() / 10), -> box 3, 4
  #
  # HOW DOES IT WORK?
  # Example: in
  #   rotate 3, wave pulse / 10, -> box 3, 4
  # 1) the part between the qualifiers and the function chaining
  # is isolated:
  #   3, wave pulse / 10
  # then a count is made of the expressions and
  # user functions accepting arguments followed by
  # a space, which
  # in this case is 1 (wave)
  # 2) then 1 closing parens is added before the chaining:
  #   rotate 3, wave pulse / 10), -> box 3, 4
  # 3) then an open parens replaces each
  # expression or user function followed by a space:
  #   rotate 3, wave(pulse / 10), -> box 3, 4
  avoidLastArgumentInvocationOverflowing: (code, error, userDefinedFunctionsWithArguments) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    expsAndUserFunctionsWithArgs =  @expressionsRegex + userDefinedFunctionsWithArguments
    qualifyingFunctionsRegex = @qualifyingCommandsRegex + userDefinedFunctionsWithArguments

    # this transformation is to handle the case
    #   f = (a,b)-> rotate a run b
    #   f 2 * sin time, <ball>
    # where the second line is transformed into
    #   f 2 * sin(time), ball
    rx = RegExp(",\\s*(\\()("+@primitivesRegex+")",'g')
    code = code.replace(rx, ", ->★$2")

    rx = RegExp(", *->",'g')
    code = code.replace(rx, "☆")

    while code != previousCodeTransformations
      previousCodeTransformations = code


      # find the code between the qualifier and the
      # arrow
      rx = RegExp("("+qualifyingFunctionsRegex+")([^☆\\r\\n]*)(☆)",'')
      match = rx.exec code
      
      if not match
        code = code.replace(rx, "$1$2, →")
        continue

      match2 = match[2]

      # within that snippet of code, search for
      # qualifiers and user functions followed by a space
      # so to determine how many parens need to be added
      rx2 = RegExp("(("+expsAndUserFunctionsWithArgs+") +)",'g')
      match3 = match2.match(rx2)
      
      if not match3
        code = code.replace(rx, "$1$2, →")
        continue

      numOfExpr = match3.length

      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing--1 number of matches: " + match3.length
      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing--1 finding qualifiers in: " + match2
      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing--1 finding using regex: " + rx2
      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing--1 number of parens to add: " + numOfExpr

      # add the closing parens
      code = code.replace(rx, "$1$2"+(Array(numOfExpr+1).join(")"))+"$3")

      # now add all the opening parens.
      # Note that there might be more than one parens to be
      # added for example in
      #   rotate 3, wave wave 2 box 3, 4
      for i in [0...numOfExpr]
        rx = RegExp("("+qualifyingFunctionsRegex+")([^☆]*)(("+expsAndUserFunctionsWithArgs+") +)([^☆\\r\\n]*)(☆)",'')
        if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing-0 regex: " + rx
        if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing-0 on: " + code
        
        code = code.replace(rx, "$1$2$4($5☆")

      rx = RegExp("("+qualifyingFunctionsRegex+")([^☆]*)(("+expsAndUserFunctionsWithArgs+") *)([^☆\\r\\n]*)(☆)",'')
      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing-0.5 regex: " + rx
      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing-0.5 on: " + code
      # finally, we change the arrow so that
      # we don't come back to this snippet of code again
      code = code.replace(rx, "$1$2$4$5, →")

      if detailedDebug then console.log "avoidLastArgumentInvocationOverflowing-1\n" + code + " error: " + error
      #alert match2 + " num of expr " + numOfExpr + " code: " + code

    code = code.replace(/☆/g, ", ->")
    code = code.replace(/→/g, "->")
    code = code.replace(/, ->★/g, ", (")

    while code != previousCodeTransformations
      previousCodeTransformations = code
      code = code.replace(/\(\(\)\)/g, "()")

    return [code, error]


  # see the comment next to ifFunctional definition
  # to see what we are trying to achieve here.
  substituteIfsInBracketsWithFunctionalVersion: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    code = code.replace(/(\w+\s*=\s*<\s*if\s*.*)>(.*>)/g, "$1›$2")
    code = code.replace(/(\w+)\s*=\s*<\s*if\s*(.*)(>)/g, "$1 = ifFunctional($2>)")
    code = code.replace(/(\w+\s*=\s*ifFunctional\s*.*)then(.*>\))/g, "$1,<$2")
    code = code.replace(/(\w+\s*=\s*ifFunctional\s*.*)else(.*>\))/g, "$1>, <$2")
    code = code.replace(/›/g, ">")

    if detailedDebug then console.log "substituteIfsInBracketsWithFunctionalVersion-1\n" + code + " error: " + error

    return [code, error]

  # not used at the moment, but it could be used in case all functions
  # belong to another object/scope, for example if you wanted
  #   LCLAPIs.box
  preprocessAndBindFunctionsToThis: (code, bracketsVariables) ->

    [code, error] = @preprocess code, bracketsVariables
    # if there is an error, just propagate it
    return [undefined, error] if error?

    rx = RegExp("(|[^\w\d\r\n])("+(@allCommandsRegex)+")(|[^\w\d\r\n])",'g')

    code = code.replace(rx, "$1@$2$3")
    if detailedDebug then console.log "preprocessAndBindFunctionsToThis\n" + code + " error: " + error

    return [code, error]


  preprocess: (code, bracketsVariables) ->
    # we'll keep any errors in here as we transform the code
    # as soon as there is any error, all next stages of
    # transformation do nothing
    error = undefined

    if detailedDebug then console.log "preprocess-0\n" + code + " error: " + error

    [code, stringsTable, error] = @removeStrings(code, error)
    if detailedDebug then console.log "preprocess-1\n" + code + " error: " + error

    [code, error, userDefinedFunctions, userDefinedFunctionsWithArguments] = @findUserDefinedFunctions(code, error)
    if detailedDebug then console.log "preprocess-2\n" + code + " error: " + error

    [code, error, bracketsVariables, bracketsVariablesArray] = @findBracketVariables(code, error)
    if detailedDebug then console.log "preprocess-3\n" + code + " error: " + error

    #@qualifyingCommandsRegex = @qualifyingCommands + bracketsVariables
    #console.log "all commands plus bracket variables BEFORE: " + @primitivesAndMatrixRegex + bracketsVariables
    #@allCommandsRegex = @allCommandsRegex + bracketsVariables
    #console.log "all commands plus bracket variables: " + @primitivesAndMatrixRegex + bracketsVariables

    [code, codeWithoutStringsOrComments, error] = @stripCommentsAndStrings(code, error)
    if detailedDebug then console.log "preprocess-4\n" + code + " error: " + error
    [code, error] = @removeTickedDoOnce(code, error)
    if detailedDebug then console.log "preprocess-5\n" + code + " error: " + error
    [code, error] = @checkBasicSyntax(code, codeWithoutStringsOrComments, error)
    if detailedDebug then console.log "preprocess-6\n" + code + " error: " + error

    [code, error] = @substituteIfsInBracketsWithFunctionalVersion(code, error)
    if detailedDebug then console.log "preprocess-6.5\n" + code + " error: " + error

    [code, error] = @removeDoubleChevrons(code, error)
    if detailedDebug then console.log "preprocess-7\n" + code + " error: " + error

    [code, error] = @rearrangeColorCommands(code, error)
    if detailedDebug then console.log "preprocess-8\n" + code + " error: " + error

    # allow some common command forms can be used in postfix notation, e.g.
    #   60 bpm
    #   red fill
    #   yellow stroke
    #   black background
    #[code, error] = @adjustPostfixNotations(code, error)
    #if detailedDebug then console.log "preprocess-9\n" + code + " error: " + error


    [code, error] = @normaliseTimesNotationFromInput(code, error)
    if detailedDebug then console.log "preprocess-10\n" + code + " error: " + error

    [code, error] = @checkBasicErrorsWithTimes(code, error)
    if detailedDebug then console.log "preprocess-11\n" + code + " error: " + error
    


    # Note that coffeescript allows you to split arguments
    # over multiple lines.
    # So if you have:
    #   rotate 0,0,1
    #   box
    # and you want to add a scale like so:
    #   scale 2,2,2
    #   rotate 0,0,1
    #   box
    # What happens is that as you are in the middle of typing:
    #   scale 2,
    #   rotate 0,0,1
    #   box
    # coffeescript takes the rotate as the second argument of scale
    # This doesn't seem to be a problem, but worth noting.


    # Each doOnce block, when run, pushes its own line number to a particular
    # array. It leaves traces of which doOnce block has been run and
    # where exactly it is so that we can go back and mark it with a tick
    # (which prevents a second run to happen, as the tickmarks expand into
    # line comments).
    if detailedDebug then console.log "preprocess-12\n" + code + " error: " + error
    [code, error] = @addTracingInstructionsToDoOnceBlocks(code, error)

    [ignore,a,ignore] = @identifyBlockStarts code, error
    [code, error] = @completeImplicitFunctionPasses code, a, error, userDefinedFunctionsWithArguments, bracketsVariables
    if detailedDebug then console.log "completeImplicitFunctionPasses:\n" + code + " error: " + error

    [code, error] = @bindFunctionsToArguments(code, error, userDefinedFunctionsWithArguments)
    if detailedDebug then console.log "preprocess-13\n" + code + " error: " + error
    [code, error] = @transformTimesSyntax(code, error)
    if detailedDebug then console.log "preprocess-14\n" + code + " error: " + error
    [code, error] = @transformTimesWithVariableSyntax(code, error)
    if detailedDebug then console.log "preprocess-15\n" + code + " error: " + error
    [code, error] = @unbindFunctionsToArguments(code, error)
    if detailedDebug then console.log "preprocess-16\n" + code + " error: " + error
    [code, error] = @findQualifiers(code, error,bracketsVariables)
    if detailedDebug then console.log "preprocess-17\n" + code + " error: " + error
    [code, error] = @fleshOutQualifiers(code, error,bracketsVariables, bracketsVariablesArray)
    if detailedDebug then console.log "preprocess-18\n" + code + " error: " + error
    [code, error] = @adjustFunctionalReferences(code, error, userDefinedFunctions, bracketsVariables)
    if detailedDebug then console.log "preprocess-19\n" + code + " error: " + error
    [code, error] = @addCommandsSeparations(code, error, userDefinedFunctions)
    if detailedDebug then console.log "preprocess-20\n" + code + " error: " + error
    [code, error] = @adjustImplicitCalls(code, error, userDefinedFunctions, userDefinedFunctionsWithArguments, bracketsVariables)
    if detailedDebug then console.log "preprocess-21\n" + code + " error: " + error
    [code, error] = @adjustDoubleSlashSyntaxForComments(code, error)
    if detailedDebug then console.log "preprocess-22\n" + code + " error: " + error
    [code, error] = @evaluateAllExpressions(code, error, userDefinedFunctions)
    if detailedDebug then console.log "preprocess-23\n" + code + " error: " + error
    [code, error] = @avoidLastArgumentInvocationOverflowing(code, error, userDefinedFunctionsWithArguments)
    if detailedDebug then console.log "preprocess-24\n" + code + " error: " + error
    [code, error] = @fixParamPassingInBracketedFunctions(code, error, userDefinedFunctions)
    if detailedDebug then console.log "preprocess-25\n" + code + " error: " + error
    [code, error] = @putBackBracketVarOriginalName(code, error)
    if detailedDebug then console.log "preprocess-26\n" + code + " error: " + error
    [code, error] = @addScopeToTimes(code, error)
    if detailedDebug then console.log "preprocess-27\n" + code + " error: " + error
    [code, error] = @beautifyCode(code, error)
    if detailedDebug then console.log "preprocess-28\n" + code + " error: " + error
    
    # unfortunately some beautification depends on the () being there
    # so we need to put this function here after the beautification step
    # TODO perhaps the ()-dependant beautifications are not really
    # beautifications and can be moved outside... BEFORE beautification
    # so we can have
    #  - parens-dep stuff beaut
    #  - simplifyFunctionDoingSimpleInvocation
    #  - other beautification
    # it would be better to have beautification as the very last step
    [code, error] = @simplifyFunctionDoingSimpleInvocation(code, error, userDefinedFunctions)
    if detailedDebug then console.log "preprocess-29\n" + code + " error: " + error

    [code, error] = @simplifyFunctionsAloneInParens(code, error, userDefinedFunctions, bracketsVariables)
    if detailedDebug then console.log "preprocess-29.5\n" + code + " error: " + error

    [code, error] = @injectStrings(code, stringsTable, error)
    if detailedDebug then console.log "preprocess-29\n" + code + " error: " + error


    return [code, error, userDefinedFunctions]


  # to run the tests, just open the dev console
  # and type:
  #    testPreprocessor()
  # or
  #    testPreprocessor(rangeMin, rangeMax)
  test: (rangeMin = undefined, rangeMax = undefined) ->
      console.log "launching all tests"
      failedTests = successfulTest = knownIssues = failedIdempotency = failedMootAppends = failedMootPrepends = 0
      unless rangeMin?
        rangeMin = 0
        rangeMax = @testCases.length
      console.log "launching tests: " + [rangeMin...rangeMax]
      for testCaseNumber in [rangeMin...rangeMax]
        testCase = @testCases[testCaseNumber]

        # just like in demos and tutorials, we use an
        # arrow to represent tabs so it's more
        # readable when looking at the examples.
        # We replace it with tabs here.
        testCase.input = testCase.input.replace(/\u25B6/g, "\t")
        if testCase.expected?
          testCase.expected = testCase.expected.replace(/\u25B6/g, "\t")

        [transformed, error, userDefinedFunctions] = @preprocess(testCase.input)
        # only check idempotency if there was no error
        # in the first step and if the test case
        # has no "notIdempotent" flag
        testIdempotency = !error? and !(testCase.notIdempotent?)
        testMoots = !error? and !(testCase.failsMootAppends?)
        #testIdempotency = false
        if testIdempotency
          [transformedTwice, error, ] = @preprocess(transformed.replace(/;/g,""))

        expressionsAndUserDefinedFunctionsRegex = @expressionsRegex + userDefinedFunctions
        allFunctionsRegex = @allCommandsRegex + "|" + expressionsAndUserDefinedFunctionsRegex
        
        if testMoots
          appendString = 's'
          prependString = 't'

          [mootInput, ignore, errorMoot] = @stripCommentsAndStrings(testCase.input,nil)
          [mootInput, ignore, errorMoot] = @beautifyCode(mootInput,errorMoot)

          if !errorMoot?
            rx = RegExp("(("+allFunctionsRegex+"|times|doOnce)([^\\w\\d]|$))",'gm');
            mootInputAppend = mootInput.replace(rx, "$2"+appendString+"$3")
            mootInputPrepend = mootInput.replace(rx, prependString+"$2$3")

            mootInputAppend = @normaliseCode(mootInputAppend,nil)[0]
            [transformedMootAppend, errorMootAppend,] = @preprocess(mootInputAppend)
            mootInputPrepend = @normaliseCode(mootInputPrepend,nil)[0]
            [transformedMootPrepend, errorMootPrepend,] = @preprocess(mootInputPrepend)            

          if !errorMootAppend?
            if userDefinedFunctions != ""
              rx = RegExp("("+userDefinedFunctions+")"+appendString+"\\(\\)",'gm');
              transformedMootAppend = transformedMootAppend.replace(rx, "$1"+appendString)
            transformedMootAppend = @stripCommentsAndStrings(transformedMootAppend,nil)[0]
            if mootInputAppend != transformedMootAppend
              failedMootAppends++
              console.log "unexpected transformation"
              console.log "moot input:\n" + mootInputAppend
              console.log "transformed into:\n" + transformedMootAppend          

          if !errorMootPrepend? and testMoots
            if userDefinedFunctions != ""
              rx = RegExp(prependString+"("+userDefinedFunctions+")\\(\\)",'gm');
              transformedMootPrepend = transformedMootPrepend.replace(rx, prependString+"$1")            
            transformedMootPrepend = @stripCommentsAndStrings(transformedMootPrepend,nil)[0]
            if mootInputPrepend != transformedMootPrepend
              failedMootPrepends++
              console.log "unexpected transformation"
              console.log "moot input:\n" + mootInputPrepend
              console.log "transformed into:\n" + transformedMootPrepend          


        if transformed == testCase.expected and
            error == testCase.error and
            (transformed == transformedTwice or !testIdempotency)
          console.log "testCase #{testCaseNumber}: pass"
          successfulTest++
        else
          if testCase.knownIssue
            console.log "!!!!!!!!!! testCase #{testCaseNumber} known fail"
            knownIssues++
          else
            console.log "!!!!!!!!!! testCase #{testCaseNumber} fail:"
            if testIdempotency and transformed != transformedTwice
              if transformed == testCase.expected
                failedIdempotency++
                console.log "\nNot idempotent but 1st result OK\n"
              else
                console.log "\nNot idempotent and 1st result not OK\n"
              console.log "\n 2nd run result: \n"
              console.log transformedTwice
            console.log '\ninput: \n' + testCase.input \
              + '\nobtained: \n' + transformed \
              + '\nwith error:\n' + error \
              + '\ninstead of:\n' + testCase.expected \
              + '\nwith error:\n' + testCase.error
            failedTests++
      console.log "========= summary ========="
      console.log "      passed: #{successfulTest}"
      console.log "      failed: #{failedTests}"
      console.log "      failed moot appends: #{failedMootAppends}"
      console.log "      failed moot prepends: #{failedMootPrepends}"
      console.log "      out of which only idempotency fails: #{failedIdempotency}"
      console.log "known issues: #{knownIssues}"
      return

  # finds each possible block start
  identifyBlockStarts: (code, error) ->
    # if there is an error, just propagate it
    return [undefined, undefined, error] if error?

    sourceByLine = code.split("\n")
    startOfPreviousLine = ""
    linesWithBlockStart = []
    
    for eachLine in [0...sourceByLine.length]
      line = sourceByLine[eachLine]
      #console.log "checking " + line
      rx = RegExp("^(\\s*)",'gm')
      match = rx.exec line
      continue if not match?
      startOfThisLine = match[1]
      #console.log "start of line: >" + startOfThisLine + "<"
      if startOfThisLine.length > startOfPreviousLine.length
        linesWithBlockStart.push eachLine-1
        blockStart = eachLine-1
        #blockEnd = @identifyBlockEnd(sourceByLine, eachLine)
        #console.log 'block ' + blockStart + ' to ' + blockEnd
      startOfPreviousLine = startOfThisLine

    #console.log "code lenght at identifyBlockStarts: " + code.split("\n").length
    return [code, linesWithBlockStart, undefined]

  # we might not need this function, leaving it here,
  # mute for the moment.
  # finds where the block starting at line "startLine" ends
  identifyBlockEnd: (sourceByLine, startLine) ->
    # if there is an error, just propagate it
    return [undefined, undefined, error] if error?

    rx = RegExp("^(\\s*)",'gm')
    match = rx.exec sourceByLine[startLine]
    #console.log "start of line: >" + startOfThisLine + "<"
    lengthToBeat = (match[1]).length

    linesWithBlockStart = []
    
    for eachLine in [startLine...sourceByLine.length]
      line = sourceByLine[eachLine]
      rx = RegExp("^(\\s*)",'gm')
      match = rx.exec line
      continue if not match?
      startOfThisLine = match[1]
      if startOfThisLine.length < lengthToBeat
        return eachLine - 1

    bottomOfProgram = sourceByLine.length-1
    return bottomOfProgram

  completeImplicitFunctionPasses: (code, linesWithBlockStart, error, userDefinedFunctionsWithArguments, bracketsVariables) ->
    # if there is an error, just propagate it
    return [undefined, error] if error?

    qualifyingFunctions = @primitivesAndMatrixRegex + userDefinedFunctionsWithArguments + bracketsVariables

    sourceByLine = code.split("\n")
    transformedLines = []
    
    countingLines = -1;
    for line in sourceByLine
      countingLines++
      if countingLines in linesWithBlockStart
        #console.log "checking " + line
        
        # if the line already ends with an arrow
        # then there is nothing to do
        rx = RegExp("->\\s*$",'gm')
        match = rx.exec line
        if match?
          transformedLines.push line
          continue

        # if the line already ends with "times"
        # then stay away from this transformation
        rx = RegExp("[^\\w\\d\\r\\n]times\\s*$",'gm')
        match = rx.exec line
        if match?
          transformedLines.push line
          continue

        # case where the function-block is passed as first argument
        # so no comma is needed
        rx = RegExp("(^|;| )\\s*("+qualifyingFunctions+")\\s*$",'gm')
        match = rx.exec line
        if match?
          transformedLines.push line+" ->"
          continue

        # case where the function-block is passed as argument beyond
        # the first, so a comma is needed
        rx = RegExp("(^|;| )\\s*("+qualifyingFunctions+")(?![\\w\\d])([^;\r\n]*)$",'gm')
        match = rx.exec line
        if match?
          transformedLines.push line+", ->"
          continue

        # if we are here is means that there was no match
        # meaning that there is nothing to add.
        transformedLines.push line

      else
        transformedLines.push line

    transformedCode = transformedLines.join "\n"

    #console.log "code lenght at completeImplicitFunctionPasses: " + transformedCode.split("\n").length
    return [transformedCode, undefined]

