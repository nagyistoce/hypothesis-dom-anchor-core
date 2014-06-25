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

    # Create buckets for various groups of anchors
    @orphans = []      # Orphans
    @halfOrphans = []  # Half-orphans
    @anchors = {}      # Anchors on a given page

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
    anchoringStrategies: @_anchoringStrategies.map (c) -> c.name

  # Public: prepare the documenty access strategy for usage
  prepare: (reason) =>
    @init()
    @domMapper.prepare reason

  # Public: describe a segement with a list of selectors,
  # created by the registered selector creators
  getSelectorsForSegment: (segmentDescription) =>
    unless segmentDescription?
      throw new Error "Can't describe a NULL segment description!"
    unless segmentDescription.type?
      throw new Error "Can't describe a segment description with missing type!"
    new Promise (resolve, reject) =>
      Promise.all(@_selectorCreators.map (creator) =>
        @_createSelectorsFromSegment segmentDescription, creator
      ).then (results) ->
        selectors = Util.flatten results
        if selectors.length
          resolve selectors
        else
          reject "No selector creator could describe this '" +
            segmentDescription.type + "' segment."

  # Public: create an anchor from a list of selectors
  createAnchor: (selectors, payload) ->
    unless selectors?
      throw new Error "Trying to create an anchor for null selector list!"

    new Promise (resolveAll, rejectAll) =>
      @_anchoringStrategies.reduce((sequence, strategy) =>
        sequence.then ->
          new Promise (resolve, reject) ->
            console.log "Executing strategy '" + strategy.name + "'..."
            try
              Promise.cast(strategy.createAnchor selectors).then (result) ->
                if result
                  reject # Break the cycle. We have a solution
                    type: "we are good"
                    data: result
                else
                  resolve() # Continue with the search
              , (error) ->
                resolve() # Continue with the search
            catch error
              console.log "While executing strategy '" + strategy.name + "',", error.stack ? error
              resolve() # Continue with the search
      , Promise.resolve())
      .then ->
        rejectAll "We could not create an anchor from these selectors."
      , (error) ->
        if error.type is "we are good"
          anchor = error.data
          anchor.payload = payload
          # TODO: do various other magic
          resolveAll anchor # Actually return the anchor
        else
          rejectAll error


  # ========= Interfaces for registering plugins

  # Public: register a selector creator. See docs.
  registerSelectorCreator: (selectorCreator) =>
    unless selectorCreator
      throw new Error "Can't register a NULL selector creator!"
    selectorCreator.configure? this
    @_selectorCreators.push selectorCreator
    this

  # Public: register a document access strategy. See docs.
  registerDocumentAccessStrategy: (strategy) =>
    unless strategy
      throw new Error "Can't register a NULL document access strategy!"
    strategy.priority ?= 50
    strategy.configure? this
    @_documentAccessStrategies.push strategy
    @_documentAccessStrategies.sort (s1, s2) -> s1.priority > s2.priority
    this

  # Public: register an anchoring strategy. See docs.
  registerAnchoringStrategy: (strategy) =>
    unless strategy
      throw new Error "Can't register a NULL anchoring strategy!"
    strategy.configure? this
    strategy.priority ?= 50
    @_anchoringStrategies.push strategy
    @_anchoringStrategies.sort (s1, s2) -> s1.priority - s2.priority
    this

  # Public: register a highligher engine. See docs.
  registerHighlighterEngine: (engine) =>
    unless engine
      throw new Error "Can't register a NULL highlighter engine!"
    engine.configure? this
    engine.priority ?= 50
    @_highlighterEngines.push engine
    @_highlighterEngines.sort (h1, h2) -> h1.priority - h2.priority
    this

  # Public: convenience method to register any kind of plugin
  register: (plugins...) ->
    plugins.forEach (plugin) =>
      unless plugin?
        throw new Error "Trying to register null plugin!"

      understood = false

      # Can this plugin be used as a document access strategy?
      if plugin.applicable? and plugin.get?
        @registerDocumentAccessStrategy plugin
        understood = true

      # Can this plugin be used as a selector creator?
      if plugin.createSelectors?
        @registerSelectorCreator plugin
        understood = true

      # Can this plugin be used as an anchoring strategy?
      if plugin.createAnchor?
        @registerAnchoringStrategy plugin
        understood = true

      # Can this plugin be used as a highlighter engine?
      # TODO

      unless understood
        console.warn "I don't recognize this plugin:", plugin

    # Return self for chaining
    this

  # ========= Private fields and methods ====

  # Private list of registered selector creators
  _selectorCreators: []

  # Private: try to create selectors for a segment using a selector creator.
  # Apply some error handling
  _createSelectorsFromSegment: (segmentDescription, creator) ->
    new Promise (resolve, reject) ->
      Promise.resolve().then( ->
        creator.createSelectors segmentDescription
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

  # Private list of registered anchoring strategies
  _anchoringStrategies: []

  # Private list of registered highlighter engines
  _highlighterEngines: []

  # Do some normalization to get a "canonical" form of a string.
  # Used to even out some browser differences.
  _normalizeString: (string) -> string.replace /\s{2,}/g, " "


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
  createSelectors: (segmentDescription) ->
    if segmentDescription.type is "dummy"
      type: "DummySelector"
      data: segmentDescription.data
    else
      []

class Anchors.Dummy.SucceedingAnchoringStrategy
  name: "Succeeding dummy anchoring strategy"

  createAnchor: (selectors) ->
    type: "Dummy anchor"

class Anchors.Dummy.FailingAnchoringStrategy1
  name: "Failing anchoring strategy (null)"

  createAnchor: (selectors) ->
    null

class Anchors.Dummy.FailingAnchoringStrategy2
  name: "Failing anchoring strategy (exception)"

  createAnchor: (selectors) ->
    throw new Error "wtf"

class Anchors.Dummy.FailingAnchoringStrategy3
  name: "Failing anchoring strategy (failed promise)"

  createAnchor: (selectors) ->
    new Promise (resolve, reject) ->
      reject()

module.exports = Anchors
