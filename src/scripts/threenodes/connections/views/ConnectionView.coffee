_ = require 'Underscore'
Backbone = require 'Backbone'

require 'jquery.ui'

### Connection View ###
class ConnectionView extends Backbone.View
  initialize: (options) ->
    super
    @container = $("#graph")
    @line = ThreeNodes.UI.UIView.svg.path().attr
      stroke: "#555"
      fill: "none"
    # set the dom element
    @el = @line.node
    @model.bind("render", () => @render())
    @model.bind("destroy", () => @remove())
    @render()

  remove: ->
    if ThreeNodes.UI.UIView.svg && @line
      @line.remove()
      delete @line
    return true

  render: () ->
    if ThreeNodes.UI.UIView.svg && @line && @line.attrs
      @line.attr
        path: @getPath()
    @

  getFieldPosition: (field) ->
    if !field.button
      console.log "no button"
      console.log field
      return {left: 0, top: 0}
    o1 = $(".inner-field span", field.button).offset()
    #console.log field.button
    if !o1
      console.log "no o1"
      return {left: 0, top: 0}
    diff = 3
    o1.top += diff
    o1.left += diff
    return o1

  getPath: () ->
    f1 = @getFieldPosition(@model.from_field)
    f2 = @getFieldPosition(@model.to_field)

    offset = $("#container-wrapper").offset()
    ofx = $("#container-wrapper").scrollLeft() - offset.left
    ofy = $("#container-wrapper").scrollTop() - offset.top
    x1 = f1.left + ofx
    y1 = f1.top + ofy
    x4 = f2.left + ofx
    y4 = f2.top + ofy
    min_diff = 42
    diffx = Math.max(min_diff, x4 - x1)
    diffy = Math.max(min_diff, y4 - y1)

    x2 = x1 + diffx * 0.5
    y2 = y1
    x3 = x4 - diffx * 0.5
    y3 = y4

    ["M", x1.toFixed(3), y1.toFixed(3), "C", x2, y2, x3, y3, x4.toFixed(3), y4.toFixed(3)].join(",")

module.exports = ConnectionView
