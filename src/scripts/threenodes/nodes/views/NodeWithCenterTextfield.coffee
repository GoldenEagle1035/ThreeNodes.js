_ = require 'Underscore'
Backbone = require 'Backbone'

require '../models/Node'
NodeView = require './NodeView'

class NodeWithCenterTextfield extends NodeView
  initialize: (options) =>
    super
    field = @getCenterField()
    container = $("<div><input type='text' data-fid='#{field.get('fid')}' /></div>").appendTo($(".center", @$el))
    f_in = $("input", container)
    field.on_value_update_hooks.update_center_textfield = (v) ->
      if v != null
        f_in.val(v.toString())
    f_in.val(field.getValue())
    if field.get("is_output") == true
      f_in.attr("disabled", "disabled")
    else
      f_in.keypress (e) ->
        if e.which == 13
          field.setValue($(this).val())
          $(this).blur()
    @

  # View class can override this. Possibility to reuse this class
  getCenterField: () => @model.fields.getField("in")

module.exports = NodeWithCenterTextfield
