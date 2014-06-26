#BackboneEvents = require('backbone-events-standalone')
Util = require './util'
Promise = require('es6-promise').Promise
ArraySet = Util.ArraySet

# Top class to export for module interface
Anchors = {}

# Info pack about a payload
class PayloadData

  constructor: (@payload) ->
    @found = []
    @missing = []

  isOrphan: -> !@found.length and @missing.length

  isHalfOrphan: -> @found.length and @missing.length

  isAnchored: -> @found.length and !@missing.length

  anchoredNew: (selectors, extraInfo, anchor) ->
    @found.push
      selectors: selectors
      extraInfo: extraInfo
      anchor: anchor

  failedToAnchorNew: (selectors, extraInfo) ->
    @missing.push
      selectors: selectors
      extraInfo: extraInfo

# Anchor manager
class Anchors.Manager

  # ========= Constructor and destructor =======================
  constructor: (@element) ->
    unless @element?
      throw new Error "Element missing!"
    console.log "Creating anchors manager for", @element

    # Payloads we have encountered
    @_payload = {}

    # Anchors on a given page
    @anchors = {}

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
    @_document.prepare reason

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
  createAnchor: (selectors, payload = null, extraInfo = null) ->
    unless selectors?
      throw new Error "Trying to create an anchor for null selector list!"

    if payload? then @_registerPayload payload

    new Promise (resolve, reject) =>
      # Go over all the anchoring strategies, until one succeeds to
      # create an anchor from these selectors
      Util.searchUntilFirst(
        @_anchoringStrategies,
        (s) => @_createAnchorWith(selectors, s)
      ).then (result) =>
        # We have an anchor
        anchor = result.data

        # Fill in some fields on the anchor
        anchor.manager = this
        anchor.strategy = result.elem # Note the strategy which worked
        anchor.payload = payload
        if extraInfo
          anchor.extraInfo = extraInfo

        # Prepare the map for the hlighlights
        anchor.highlight = {}

        # Store the anchor for all involved pages
        for pageIndex in [anchor.startPage .. anchor.endPage]
          @anchors[pageIndex] ?= []
          @anchors[pageIndex].push anchor

        # Save the info about the payload
        if payload?
          @_payload[payload].anchoredNew selectors, extraInfo, anchor

        resolve anchor
      , (error) =>
        console.log "Could not create anchor for payload", payload
        # Save the info about the payload
        if payload?
          @_payload[payload].failedToAnchorNew selectors, extraInfo

        reject error

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

  # ========= Fields and methods intended to be used by plugins ====

  # Do some normalization to get a "canonical" form of a string.
  # Used to even out some browser differences.
  _normalizeString: (string) -> string.replace /\s{2,}/g, " "

  # Find the given type of selector from an array of selectors.
  # If it does not exist, null is returned.
  _findSelector: (selectors, type) ->
    selectors.filter((s) -> s.type is type)[0]

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
          "'" + creator.name + "':", error?.stack ? error
        resolve []
      )

  # Private list of registered document access strategies
  _documentAccessStrategies: []

  # Private: select the document access strategy to use
  _chooseAccessPolicy: =>
    # We only have to do this once.
    return if @_document

    # Go over the available strategies
    for s in @_documentAccessStrategies
      # Can we use this strategy for this document?
      if s.applicable()
#        @documentAccessStrategy = s
        console.log "Selected document access strategy: " + s.name
        @_document = s.get()
        document.addEventListener "docPageMapped", (evt) =>
          @_realizePage evt.pageIndex
        document.addEventListener "docPageUnmapped", (evt) =>
          @_virtualizePage evt.pageIndex
        
        return this

  # Private list of registered anchoring strategies
  _anchoringStrategies: []

  # Private: try to create an anchor with a given strategy
  _createAnchorWith: (selectors, strategy, verbose) ->
    new Promise (resolve, reject) -> # Create a wrapper promise
      try # Apply some error handling
        if verbose
          console.log "Executing strategy '" + strategy.name + "'..."
        Promise.cast(strategy.createAnchor selectors) # Cast it into a promise
          .then (anchor) ->
            # Did we get something real?
            if anchor?
              # Do we have all the fields?
              if anchor.type? and anchor.startPage? and
                  anchor.endPage? and anchor.quote?
                anchor.strategy = strategy
                # Return the created anchor
                resolve anchor
              else
                # No, some fields are missing
                console.warn "Strategy", "'" + strategy.name + "'",
                  "has returned an anchor without the mandatory fields.",
                  anchor
                reject "missing fields"
            else
              # No, we got a null pointer
              if verbose then console.log "Strategy returned null"
              reject "returned null"
          , (error) ->
             if verbose then console.log "Strategy was rejected:",
               error?.stack ? error
             reject error # The promise was rejected
      catch error
        # We got an exception while executing the strategy
        console.warn "While executing strategy '" + strategy.name + "',",
          error?.stack ? error
        reject error?.stack ? error

  # Private list of registered highlighter engines
  _highlighterEngines: []

  # Private: make sure we have a record about a payload
  _registerPayload: (payload) ->
    @_payload[payload] ?= new PayloadData(payload)


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
    startPage: 0
    endPage: 0
    quote: "dummy quote"

class Anchors.Dummy.FailingAnchoringStrategy1
  name: "Failing anchoring strategy (null)"

  createAnchor: -> null

class Anchors.Dummy.FailingAnchoringStrategy2
  name: "Failing anchoring strategy (exception)"

  createAnchor: -> throw new Error "wtf"

class Anchors.Dummy.FailingAnchoringStrategy3
  name: "Failing anchoring strategy (failed promise)"

  createAnchor: -> new Promise (resolve, reject) -> reject()

class Anchors.Dummy.FailingAnchoringStrategy4
  name: "Failing anchoring strategy (missing fields)"

  createAnchor: ->
    type: "Dummy anchor"
    startPage: 0
    endPage: 0

module.exports = Anchors
