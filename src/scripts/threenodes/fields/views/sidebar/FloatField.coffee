#"use strict"
_ = require 'Underscore'
Backbone = require 'Backbone'
namespace = require('libs/namespace').namespace

BaseField = require 'threenodes/fields/views/sidebar/BaseField'

### FloatField View ###
class FloatField extends BaseField
  initialize: (options) ->
    super

  render: () =>
    $target = @createSidebarContainer()
    #console.log @model
    if @model.attributes.possibilities
      @create_sidebar_select($target)
    else
      @create_sidebar_input($target)
    true

  create_sidebar_select: ($target) =>
    self = this
    input = "<div><select>"
    for f of @model.get("possibilities")
      dval = @model.get("possibilities")[f]
      if dval == @val
        input += "<option value='#{dval}' selected='selected'>#{f}</option>"
      else
        input += "<option value='#{dval}'>#{f}</option>"
    input += "</select></div>"
    $target.append(input)
    $("select", $target).change (e) =>
      @model.setValue($("select", $target).val())
    return true

  create_sidebar_input: ($target) =>
    @textfield = @createTextfield($target)
    @textfield.linkTextfieldToVal()

module.exports = FloatField
