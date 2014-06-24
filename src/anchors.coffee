#BackboneEvents = require('backbone-events-standalone')
Util = require('./util')
Promise = require('es6-promise').Promise

# Top class to export for module interface
Anchors = {}

# Anchor manager
class Anchors.Manager

  # ========= Constructor and destructor =======================
  constructor: (@element) ->
    unless @element?
      throw new Error "Element missing!"
    console.log "Creating anchors manager for", @element

  destroy: ->
    this.stopListening()

  # ========= Interfaces for the actual work

  # Public: Initialize anchoring system
  init: =>
    @_chooseAccessPolicy()

  # Public: return information about available functionality
  getConfig: ->
    documentAccessStrategies: @_documentAccessStrategies.map (s) -> s.name
    selectorCreators: @_selectorCreators.map (c) -> c.name

  # Public: describe a segement with a list of selectors,
  # created by the registered selector creators
  getSelectorsForSegment: (segment) =>
    unless segment?
      throw new Error "Can't describe a NULL segment!"
    unless segment.type?
      throw new Error "Can't describe a segment with missing type!"
    new Promise (resolve, reject) =>
      Promise.all(@_selectorCreators.map (creator) =>
        @_describeSegment segment, creator
      ).then (results) ->
        selectors = Util.flatten results
        if selectors.length
          resolve selectors
        else
          reject "No selector creator could describe this '" +
            segment.type + "' segment."

  test: () ->
    console.log "Anchoring config is:", @getConfig()

    testSegment =
      type: "dummy"
      data: "whatever"

    @domMapper.prepare("creating selectors").then (state) =>
      elem = document.getElementsByTagName("li")[2]
      r = document.createRange()
      r.setStartBefore elem
      r.setEndAfter elem

      testSegment =
        type: "raw text range"
        range: r
        data:
          dtmState: state

      @getSelectorsForSegment(testSegment).then((result) ->
        console.log "Got selectors:", result
      ).catch((error) ->
        console.log "Error:", error
      )

  # ========= Interfaces for registering functionality

  # Public: register a selector creator. See docs.
  registerSelectorCreator: (selectorCreator) =>
    unless selectorCreator
      throw new Error "Can't register a NULL selector creator!"
    @_selectorCreators.push selectorCreator

  # Public: register a document access strategy. See docs.
  registerDocumentAccessStrategy: (strategy) =>
    unless strategy
      throw new Error "Can't register a NULL document access strategy!"
    strategy.priority ?= 50
    @_documentAccessStrategies.push strategy
    @_documentAccessStrategies.sort (s1, s2) -> s1.priority > s2.priority


  # ========= Private fields and methods ====

  # Private list of registered selector creators
  _selectorCreators: []

  # Private: try to describe a segment using a selector creator.
  # Apply some error handling
  _describeSegment: (segment, creator) ->
    new Promise (resolve, reject) ->
      Promise.resolve().then( ->
        creator.describe segment
      ).then((selectors) ->
        resolve selectors
      ).catch((error) ->
        console.log "Internal error while using selector creator",
          "'" + creator.name + "':", error.stack
        resolve []
      )

  # Private list of registered document access strategies
  _documentAccessStrategies: []

  # Private: select the document access strategy to use
  _chooseAccessPolicy: =>
    # We only have to do this once.
    return if @domMapper

    # Go over the available strategies
    for s in @_documentAccessStrategies
      # Can we use this strategy for this document?
      if s.applicable()
#        @documentAccessStrategy = s
        console.log "Selected document access strategy: " + s.name
        @domMapper = s.get()
        document.addEventListener "docPageMapped", (evt) =>
          @_realizePage evt.pageIndex
        document.addEventListener "docPageUnmapped", (evt) =>
          @_virtualizePage evt.pageIndex
        
        return this


# Collection of dummy plugins
Anchors.Dummy = {}

# Fake two-phase / pagination support, used for HTML documents,
# when dom-text-mapper is not available
class DummyDocumentAccess

  constructor: (@rootNode) ->
  @applicable: -> true
  getPageIndex: -> 0
  getPageCount: -> 1
  getPageRoot: -> @rootNode
  getPageIndexForPos: -> 0
  isPageMapped: -> true
  prepare: -> Promise.resolve()


# Default dummy strategy for simple HTML documents.
# The generic fallback.
class Anchors.Dummy.DocumentAccessStrategy
  name: "Dummy document access strategy"
  priority: 99
  applicable: -> true
  get: => new DummyDocumentAccess @element


class Anchors.Dummy.SelectorCreator
  name: "Dummy selector creator"
  describe: (selection) ->
    if selection.type is "dummy"
      type: "DummySelector"
      data: selection.data
    else
      []



module.exports = Anchors
