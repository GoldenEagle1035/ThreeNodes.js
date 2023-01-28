_ = require 'Underscore'
Backbone = require 'Backbone'
Node = require 'threenodes/nodes/models/Node'
NodeWithCenterTextfield = require 'threenodes/nodes/views/NodeWithCenterTextfield'

class Random extends NodeWithCenterTextfield
  getCenterField: () => @model.fields.getField("out", true)
ThreeNodes.Core.addNodeView('Random', Random)

class LFO extends NodeWithCenterTextfield
  getCenterField: () => @model.fields.getField("out", true)
ThreeNodes.Core.addNodeView('LFO', LFO)

class Timer extends NodeWithCenterTextfield
  getCenterField: () => @model.fields.getField("out", true)
ThreeNodes.Core.addNodeView('Timer', Timer)


class Random extends Node
  @node_name = 'Random'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = true

  getFields: =>
    base_fields = super
    fields =
      inputs:
        "min" : 0
        "max" : 1
      outputs:
        "out" : 0
    return $.extend(true, base_fields, fields)

  compute: =>
    value = @fields.getField("min").getValue() + Math.random() * (@fields.getField("max").getValue() - @fields.getField("min").getValue())
    @fields.setField("out", value)

ThreeNodes.Core.addNodeType('Random', Random)

# based on http://www.cycling74.com/forums/topic.php?id=7821
class LFO extends Node
  @node_name = 'LFO'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = true
    @rndB = Math.random()
    @rndA = @rndB
    @rndrange = 1
    @flip = 0
    @taskinterval = 1
    @taskintervalhold = 20
    @clock = 0
    @PI = 3.14159

  getFields: =>
    base_fields = super
    fields =
      inputs:
        "min" : 0
        "max" : 1
        "duration" : 1000
        "mode":
          type: "Float"
          val: 0
          values:
            "sawtooth": 0
            "sine": 1
            "triangle": 2
            "square waver": 3
            "random": 4
            "random triangle": 5
      outputs:
        "out" : 0
    return $.extend(true, base_fields, fields)

  compute: =>
    duration = @fields.getField("duration").getValue()
    min = @fields.getField("min").getValue()
    max = @fields.getField("max").getValue()
    mode = @fields.getField("mode").getValue()

    @clock = Date.now()
    time = (@taskinterval * @clock) % duration
    src = time / duration
    range = max - min
    lfoout = 0
    lfout = switch mode
      # sawtooth
      when 0 then (src * range) + min
      # sine
      when 1 then ( range * Math.sin(src * @PI)) + min
      # triangle
      when 2
        halfway = duration / 2
        if time < halfway
          (2 * src * range) + min
        else
          srctmp = (halfway - (time - halfway)) / duration
          (2 * srctmp * range) + min
      # square waver
      when 3
        low = time < duration / 2
        hi = time >= duration / 2
        low * min + hi * max
      # random
      when 4
        if time >= duration - @taskinterval
          @rndA = Math.random()
        (@rndA * range) + min
      # random triangle
      when 5
        if time < @taskinterval
          @rndA = @rndB
          @rndB = range * Math.random() + min
          @rndrange = @rndB - @rndA
        src * @rndrange + @rndA

    @fields.setField("out", lfout)

ThreeNodes.Core.addNodeType('LFO', LFO)

class Merge extends Node
  @node_name = 'Merge'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = false


  getFields: =>
    # Don't extend with base fields

    fields =
      inputs:
        "in0" : {type: "Any", val: null}
        "in1" : {type: "Any", val: null}
        "in2" : {type: "Any", val: null}
        "in3" : {type: "Any", val: null}
        "in4" : {type: "Any", val: null}
        "in5" : {type: "Any", val: null}
      outputs:
        "out" : {type: "Array", val: []}
    return fields

  compute: =>
    result = []
    changed = false
    for f of @fields.inputs
      field = @fields.inputs[f]
      subval = field.get("value")
      if subval != null && field.connections.length > 0 && field.changed == true
        changed = true
        #console.log("change")

        # if subvalue is an array append it to the result
        if jQuery.type(subval) == "array"
          result = result.concat(subval)
        else
          result[result.length] = subval
    if changed
      @fields.setField("out", result)

ThreeNodes.Core.addNodeType('Merge', Merge)

class Get extends Node
  @node_name = 'Get'
  @group_name = 'Utils'

  getFields: =>
    base_fields = super
    fields =
      inputs:
        "array" : {type: "Array", val: null}
        "index" : 0
      outputs:
        "out" : {type: "Any", val: null}
    return $.extend(true, base_fields, fields)

  compute: =>
    old = @fields.getField("out", true).getValue()
    @value = false
    arr = @fields.getField("array").getValue()
    ind = parseInt(@fields.getField("index").getValue())
    if $.type(arr) == "array"
      @value = arr[ind % arr.length]
    if @value != old
      @fields.setField("out", @value)

ThreeNodes.Core.addNodeType('Get', Get)

class Mp3Input extends Node
  @node_name = 'Mp3Input'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = true
    @counter = 0
    @playing = false

    # TODO: move this in a view
    window.AudioContext = window.AudioContext || window.webkitAudioContext
    if AudioContext
      @audioContext = new AudioContext()
    else
      $(".options", @main_view).prepend('<p class="warning">This node currently require a webaudio capable browser.</p>')
    @url_cache = ""

  getFields: =>
    base_fields = super
    fields =
      inputs:
        "url": ""
        "smoothingTime": 0.1
      outputs:
        "average" : 0
        "low" : 0
        "medium" : 0
        "high" : 0
    return $.extend(true, base_fields, fields)

  remove: () =>
    @stopSound()
    delete @audioContext
    delete @url_cache
    super

  onRegister: () ->
    super
    if @fields.getField("url").getValue() != ""
      @loadAudio(@fields.getField("url").getValue())

  stopSound: () ->
    if !@source then return false

    if @playing == true
      @source.stop(0.0)
      @source.disconnect(0)
      @playing = false

  playSound: (time) ->
    if @source && @audioContext && @audioBuffer
      @stopSound()
      @source = @createSound()
      @source.start(0, time, @audioBuffer.duration - time)
      @playing = true

  finishLoad: () =>
    @source.buffer = @audioBuffer
    @source.looping = true

    @onSoundLoad()

    Timeline.getGlobalInstance().maxTime = @audioBuffer.duration;

    # looks like the sound is not immediatly ready so add a little delay
    delay = (ms, func) -> setTimeout func, ms
    delay 1000, () =>
      # reset the global timeline when the sound is loaded
      Timeline.getGlobalInstance().stop();
      Timeline.getGlobalInstance().play();

  createSound: () =>
    src = @audioContext.createBufferSource()
    if @audioBuffer
      src.buffer = @audioBuffer
    src.connect(@analyser)
    @analyser.connect(@audioContext.destination)
    return src

  loadAudio: (url) =>
    # stop the main timeline when we start to load
    Timeline.getGlobalInstance().stop();

    @analyser = @audioContext.createAnalyser()
    @analyser.fftSize = 1024

    @source = @createSound()
    @loadAudioBuffer(url)

  loadAudioBuffer: (url) =>
    request = new XMLHttpRequest()
    request.open("GET", url, true)
    request.responseType = "arraybuffer"
    onDecoded = (buffer) =>
      @audioBuffer = buffer
      @finishLoad()

    request.onload = () =>
      #@audioBuffer = @audioContext.createBuffer(request.response, false )
      @audioContext.decodeAudioData(request.response, onDecoded)

    request.send()
    this

  onSoundLoad: () =>
    @freqByteData = new Uint8Array(@analyser.frequencyBinCount)
    @timeByteData = new Uint8Array(@analyser.frequencyBinCount)

  getAverageLevel: (start = 0, max = 512) =>
    if !@freqByteData
      return 0
    start = Math.floor(start)
    max = Math.floor(max)
    length = max - start
    sum = 0
    for i in [start..max]
      sum += @freqByteData[i]
    return sum / length

  remove: () =>
    super
    if @source
      @source.stop(0.0)
      @source.disconnect()
    @freqByteData = false
    @timeByteData = false
    @audioBuffer = false
    @audioContext = false
    @source = false


  compute: () =>
    if !window.AudioContext
      return
    if @url_cache != @fields.getField("url").getValue()
      @url_cache = @fields.getField("url").getValue()
      @loadAudio(@url_cache)
    if @analyser && @freqByteData
      @analyser.smoothingTimeConstant = @fields.getField("smoothingTime").getValue()
      @analyser.getByteFrequencyData(@freqByteData)
      @analyser.getByteTimeDomainData(@timeByteData)

    if @freqByteData
      length = @freqByteData.length
      length3rd = length / 3

      @fields.setField("average", @getAverageLevel(0, length - 1))
      @fields.setField("low", @getAverageLevel(0, length3rd - 1))
      @fields.setField("medium", @getAverageLevel(length3rd, (length3rd * 2) - 1))
      @fields.setField("high", @getAverageLevel(length3rd * 2, length - 1))
    return true

ThreeNodes.Core.addNodeType('Mp3Input', Mp3Input)

class Mouse extends Node
  @node_name = 'Mouse'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = true

  getFields: =>
    base_fields = super
    fields =
      outputs:
        "xy": {type: "Vector2", val: new THREE.Vector2()}
        "x" : 0
        "y" : 0
    return $.extend(true, base_fields, fields)

  compute: =>
    dx = ThreeNodes.renderer.mouseX
    dy = ThreeNodes.renderer.mouseY
    @fields.setField("xy", new THREE.Vector2(dx, dy))
    @fields.setField("x", dx)
    @fields.setField("y", dy)

ThreeNodes.Core.addNodeType('Mouse', Mouse)

class Screen extends Node
  @node_name = 'Screen'
  @group_name = 'Utils'

  @width: 0
  @height: 0

  @onResize: (e) ->
    Screen.width = $(window).width()
    Screen.height = $(window).height()


  initialize: (options) =>
    super
    @auto_evaluate = true
    $(window).on("resize.threenodes", Screen.onResize)
    Screen.onResize()

  remove: () =>
    super
    $(window).off("resize.threenodes")

  getFields: =>
    base_fields = super
    fields =
      outputs:
        "width" : Screen.width
        "height" : Screen.height
    return $.extend(true, base_fields, fields)

  compute: =>
    @fields.setField("width", Screen.width)
    @fields.setField("height", Screen.height)

ThreeNodes.Core.addNodeType('Screen', Screen)

class Timer extends Node
  @node_name = 'Timer'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = true
    @old = @get_time()
    @counter = 0

  getFields: =>
    base_fields = super
    fields =
      inputs:
        "reset" : false
        "pause" : false
        "max" : 99999999999
      outputs:
        "out" : 0
    return $.extend(true, base_fields, fields)

  get_time: => new Date().getTime()

  compute: =>
    oldval = @fields.getField("out", true).getValue()
    now = @get_time()
    if @fields.getField("pause").getValue() == false
      @counter += now - @old
    if @fields.getField("reset").getValue() == true
      @counter = 0

    diff = @fields.getField("max").getValue() - @counter
    if diff <= 0
      #@counter = diff * -1
      @counter = 0
    @old = now
    @fields.setField("out", @counter)

ThreeNodes.Core.addNodeType('Timer', Timer)

class Font extends Node
  @node_name = 'Font'
  @group_name = 'Utils'

  initialize: (options) =>
    super
    @auto_evaluate = true
    @ob = ""
    # todo: find a way to have cleaner path (./asset/fonts/)
    dir = "../../../../../../assets/fonts/"
    @files =
      "helvetiker":
        "normal": dir + "helvetiker_regular.typeface"
        "bold": dir + "helvetiker_bold.typeface"
      "optimer":
        "normal": dir + "optimer_regular.typeface"
        "bold": dir + "optimer_bold.typeface"
      "gentilis":
        "normal": dir + "gentilis_regular.typeface"
        "bold": dir + "gentilis_bold.typeface"
      "droid sans":
        "normal": dir + "droid/droid_sans_regular.typeface"
        "bold": dir + "droid/droid_sans_bold.typeface"
      "droid serif":
        "normal": dir + "droid/droid_serif_regular.typeface"
        "bold": dir + "droid/droid_serif_bold.typeface"
    @reverseFontMap = {}
    @reverseWeightMap = {}
    # todo: fix this
    for i of @fields.getField("weight").get("possibilities")
      @reverseWeightMap[@fields.getField("weight").get("possibilities")[i]] = i
    for i of @fields.getField("font").get("possibilities")
      @reverseFontMap[@fields.getField("font").get("possibilities")[i]] = i

    @fontcache = -1
    @weightcache = -1

  getFields: =>
    base_fields = super
    fields =
      inputs:
        "font":
          type: "Float"
          val: 0
          values:
            "helvetiker": 0
            "optimer": 1
            "gentilis": 2
            "droid sans": 3
            "droid serif": 4
        "weight":
          type: "Float"
          val: 0
          values:
            "normal": 0
            "bold": 1
      outputs:
        "out": {type: "Any", val: @ob}
    return $.extend(true, base_fields, fields)

  remove: () =>
    delete @reverseFontMap
    delete @reverseWeightMap
    delete @ob
    super

  compute: =>
    findex = parseInt(@fields.getField("font").getValue())
    windex = parseInt(@fields.getField("weight").getValue())
    if findex > 4 || findex < 0
      findex = 0
    if windex != 0 || windex != 1
      windex = 0
    font = @reverseFontMap[findex]
    weight = @reverseWeightMap[windex]

    #if findex != @fontcache || windex != @weightcache
    #  # load the font file
    #  require [@files[font][weight]], () =>
    #    @ob =
    #      font: font
    #      weight: weight
    @ob =
      font: font
      weight: weight

    @fontcache = findex
    @weightcache = windex
    @fields.setField("out", @ob)

ThreeNodes.Core.addNodeType('Font', Font)
