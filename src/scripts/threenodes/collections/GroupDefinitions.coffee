_ = require 'Underscore'
Backbone = require 'Backbone'
Indexer = require 'threenodes/utils/Indexer'
GroupDefinition = require 'threenodes/models/GroupDefinition'

class GroupDefinitions extends Backbone.Collection
  model: GroupDefinition

  initialize: () =>
    # The group definitions have their own indexer, used to get unique id
    @indexer = new Indexer()

    @bind "group:removed", (c) =>
      @remove(c)

  removeAll: () =>
    models = @models.concat()
    _.invoke models, "remove"
    @reset([])
    @indexer.reset()

  getByGid: (gid) =>
    @find (def) -> def.get("gid") == gid

  render: () =>
    @.each (c) ->
      c.render()

  create: (model, options) =>
    if !options then options = {}
    options.indexer = @indexer
    model = @_prepareModel(model, options)
    if !model
      return false
    @add(model, options)
    return model

  groupSelectedNodes: (selected_nodes = false) =>
    # selected_nodes parameter is only given in GroupTest
    if !selected_nodes
      selected_nodes = @getSelectedNodes()

    # compute the center node position
    average_position = @getNodesAveragePosition(selected_nodes)
    dx = average_position.x
    dy = average_position.y

    # Create a new GroupDefinition from the selected nodes and connections
    group_def = new GroupDefinition
      fromSelectedNodes: selected_nodes
      indexer: @indexer
    @add(group_def)

    # Save the connection going out or in the group of nodes
    # the connections have one extenal node linked to one selected node
    external_connections = []
    external_objects = []
    for node in selected_nodes
      # check each node fields
      for field in node.fields.models
        # loop each connections since we can have multiple out connections
        for connection in field.connections
          indx1 = selected_nodes.indexOf(connection.from_field.node)
          indx2 = selected_nodes.indexOf(connection.to_field.node)
          # if "from" OR "out" is external add it
          if indx1 == -1 || indx2 == -1
            # don't add it twice
            already_exists = external_connections.indexOf(connection)
            if already_exists == -1
              external_connections.push(connection)
              connection_description = connection.toJSON()
              connection_description.to_subfield = (indx1 == -1)
              external_objects.push(connection_description)

    # remove the nodes
    for node in selected_nodes
      node.remove()

    # Create a ThreeNodes.nodes.Group
    model =
      type: "Group"
      definition: group_def
      x: dx
      y: dy
    @trigger("definition:created", model, external_objects)

    return group_def

  getSelectedNodes: () ->
    selected_nodes = []
    # Selected nodes jquery selector
    $selected = $(".node.ui-selected").not(".node .node")
    $selected.each () ->
      node = $(this).data("object")
      selected_nodes.push(node)

    return selected_nodes

  getNodesAveragePosition: (selected_nodes) ->
    # Get the average position of selected nodes
    min_x = 0
    min_y = 0
    max_x = 0
    max_y = 0

    # Selected nodes jquery selector
    $selected = $(".node.ui-selected")

    # Stop directly if there is no node selected
    if $selected.length < 1 && selected_nodes.length == 0
      return false

    # Get selected nodes
    for node in selected_nodes
      # get the x/y node min and max to place the new node at the center
      min_x = Math.min(min_x, node.get("x"))
      max_x = Math.max(max_x, node.get("x"))
      min_y = Math.min(min_y, node.get("y"))
      max_y = Math.max(max_y, node.get("y"))

    # compute the center node position
    dx = (min_x + max_x) / 2
    dy = (min_y + max_y) / 2
    return {x: dx, y: dy}

  removeAll: () =>
    @remove(@models)

module.exports = GroupDefinitions
