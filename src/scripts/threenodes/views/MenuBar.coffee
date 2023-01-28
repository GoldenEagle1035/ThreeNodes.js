#"use strict"
_ = require 'Underscore'
Backbone = require 'Backbone'
_view_menubar = require 'templates/app_menubar.tmpl.html'
require 'jquery.menubar'

class MenuBar extends Backbone.View
  @template: _view_menubar

  initialize: () ->
    @$el.menubar()

    self = this
    $("a", @$el).click (event) ->
      if $(this).next().is("ul")
        return false

      url = $(this).attr('href').substr(1)
      self.onLinkClick(event, this, url)

    $("#main_file_input_open").change (e) =>
      @trigger("LoadFile", e)

  onLinkClick: (event, link, url) =>
    data_event = $(link).data("event")
    data_attr = $(link).data("eventData")

    if data_event
      #event.preventDefault()

      @trigger(data_event, data_attr)

      # exceptions and special event handling
      switch data_event
        when "ClearWorkspace"
          Backbone.history.navigate("", false)
        when "OpenFile"
          $("#main_file_input_open").click()
      return true

    # sends "normal" urls to the router
    return true

module.exports = MenuBar
