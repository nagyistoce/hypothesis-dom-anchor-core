# dom-anchor-core

Core library code for a DOM Anchoring Framework

## Conceptual overview

This document describes the concepts, components and processes making up the DOM Anchoring Framework.

### Passive components

#### Document

This concept represent the document we are currently working with, in the given lifecycle of the DOM anchoring framework.

The framework itself does not do any kind of identification of the document.

In theory, we could work over any kind of document, but in practice, there are some modules which are tied to the DOM.
(Fortunately, not in the core itself.)

Currently supported document types are
 * Generic HTML documents
 * PDF documents rendered using PDF.js

Later we plan to support scribd, and google docs, ans several others formats, too.

#### Page

A `page` is a piece of the `document` which is rendered at the same time. 

A static HTML page is simply handled as a one-page document.

Many other document formats / platforms use lazy rendering (which means that they only render a few pages at a time, and the rest is only rendered on demand, when the user needs to see them); this practice is useful for conserving memory and CPU resources.

Our system needs to know about which pages are rendered, and which are not, so that we can react properly.

The handling of the pages is the responsibility of the `Document accesss strategies`.

#### Segment

Any part of any `document`.

A `segment` can intersect with several `pages`.

#### Load

Any object belonging to an `anchor`, passed in by client code, and stored together with the `anchor` created for it, for the convenience of the client code.

A `load` might belong to more than one `anchors`.

#### Segment description

A raw description of a `segment`.

 * All `segment descriptions` carry a `type` field, for easy recognition of the type of `segment`.
 * `Segments descriptions` are typically produced by the UI code.
 * `Segment descriptions` are supposed to be raw and unprocessed, to avoid loss of any potentially useful information. Typically, they carry DOM (or similar) objects; in many cases, they carry the original `segment` *itself*.
 * `Segment descriptions` do not have to be serializable.
 * Examples:
   * a browser native [Range](https://developer.mozilla.org/en-US/docs/Web/API/range) object, describing a part of the document the user has selected.
   * a [NormalizedRange](https://github.com/openannotation/annotator/blob/bd008609441138b162928e69541d76f6fcd45c1a/src/range.coffee#L159) object, as used in [Annotator](https://github.com/openannotation/annotator), describing the same.

#### Selector

A piece of serializable data conveying some information hopefully useful for identify a `segment`.

 * See also the definition [in the Open Annotation Data Model](http://www.openannotation.org/spec/core/specific.html#Selectors).
 * `Selectors` are created by `selector creators`, based on `segment descriptions`.
 * `Selectors` must be serializable, so no DOM object references (or similar) are allowed here.
 * `Selectors` do not have to be all-encompassing; it's permissible to conveys only partial information.
 * All `selectors` have a `type` field.

#### Anchor

A piece of information representing the results of a previous attempt to identify a `segment` in a `document`.

 * Every `anchor` is created by an `anchoring strategy`.
 * `Anchors` might or might not be serializable. (Can use DOM objects, etc.)
 * `Anchors` can also store extra information about how the current content of the `document` compares to the state captured in the `selectors`.
 * All `anchors` have a `type` field.
 * `Anchors` are represented by `highlights` in the DOM.
 * If and `anchor` intersects with several `pages`, then it will have different `highlights` for each page.
 * `Anchors` keep a per-`page` list of their `highlights`.
 * `Anchors` can be `virtual`, `real` or `partially real`, depending on whether or not the corresponding `highlights` are rendered. (`virtual`: *no* highlights are rendered; `real`: *all* highlights are rendered; `partially real`: *some* highlights are rendered.)
 * `Anchors` can carry links to a `load`, if so desired by the client code using them.

#### Orphan load

A `load` for which no `anchor` could be created for.

#### Half-orphan load

A `load` which was mentioned by more than one anchoring attempts, but not all the requested `anchor` could be created.

#### Highlight

Visual representation of an `anchor` in the DOM.

 * `Highlights` are rendered by a `Highlighter engine`.
 * `Highlights` have some representation in the DOM, thus they are visible to the user.
 * `Highlights are active objects, and can indicate some state changes, and can interact with the user.

### Active components

#### Platform

This part is not actually part of our system, but we must know about it.

If we are not working with a static HTML document, but with an application displaying a given document type (like, for example, PDF.js, which we support for PDF documents), then we call this application the `platform`.

The `platforms` interact with, and are handled by the `Document access strategies`.

#### Document access strategy

Responsible for interacting with the `platform`.

 * Each `document access strategy` can support one or more `platforms`.
 * The `document access strategy` determines whether or not it supports the currently loaded `document`.
 * Only one `document access strategy` is active during one session of the framework.
 * The main tasks of the `document access strategies` are:
   * Provide a way to access the contents of the document. (Also called `corpus`.)
   * Notify the `manager` about document content changes.
   * Answer questions about the relations between given DOM elements, and the `corpus` of the document. (Where does DOM node X start and end in the `corpus`? Which DOM nodes are responsible for the content of the corpus between character positions X and Y?)
   * Respond to page-related questions and queries. (How many pages are there? Which pages are we on now? Let's go to to page X! Is page Y rendered? Which page does DOM node X belong to? Which page does character position Y in the corpus belong to? Where does page X start and end in the `corpus`?)
   * Notify the manager about page rendering and un-rendering events.

#### Selector creator

Responsible for describing a `segment` with [a set of] `selectors`.

 * Input: a `segment description`.
 * Output: zero or more `selectors`.
 * Typically, the `manager` works with many `selector creators` loaded simultaneously, each responsible only for translating a given type of `segment description` into a given type of `selector`.
 * Typically, more than one `selector creators` will react to any given type of `segment description`, describing the segment with different `selectors`.
 * It's also allowed to respond with a promise, which will be resolved with a list of `selectors` later.

#### Anchoring strategy

Responsible for identifying `segments` of the `document` (using the available `selectors`), and also to verify the validity of the resulting `anchor` after a `document` change.

`Anchor` creation:
 * Input:
   * a list of `selectors` describing the `segment`
   * the data extracted from the `document` using the active `document access strategy`
 * Output: an `anchor`
 * Can also respond with a promise, which will be resolved with an `anchor` later.
 * Typically, the `manager` works with several `anchoring strategies` loaded simultaneously, each responsible only for identifing the `segment` using a given method. It's perfectly OK to fail, if the the `selctors` required by the given strategy are unavailable, or if the data stored in the received `selectors` does not match with the data provided by the `document access strategy` about the `document`.

`Anchor` verification:
 * Input:
   * the `anchor`
   * the data extracted from the `document` using the active `document access strategy`
 * Output:
   * A yes-no decision signaling whether or not the `anchor` is still valid.

#### Highlighter engine

Responsible for creating the highlights

 * Input: an `anchor`
 * Output: a `highlight`
 * Several `highlighter engines` can be loaded at the same time; typically, each is only reaponsible for handling a given type of `anchor`, and might be restricted to work with a given set of `platforms`.
 * The rendering of the highlights can be an asynchronous process.
 * The generated highlight objects must implement the standard Highlight interface:
   * Get/set/reset the `temporary`/`active`/`focused` flags
   * Get information about the position and size of the highlight inside the DOM
   * Scroll the browser to this highlight 

#### Anchor Manager

Responsible for controlling all the anchoring-related processes.

Keeps lists of:
 * Current `Anchors` (per-`page`)
 * Current `Orphan loads`
 * Current `Half-orphan loads`
 * Available `document access strategies`
 * Available `selector creators`
 * Available `anchoring strategies`
 * Available `highlighter engines`

Interfaces provided for `document access strategies`:
 * Notify the manager about page rendering and un-rendering events
 * Notify the manager about document content changes

Interfaces provided for client code:
 * Register `document access strategies`
 * Register `selector creators`
 * Register `anchoring strategies`
 * Register `highlighter engines`
 * Initialize the `manager`
 * Describe a given `segment description` with `selectors`
 * Create an `anchor` from a given list of `selectors` (and optionally, store a `load` with it)
 * Remove an `anchor`
 * Get all `anchors` (for a given page)
 * Get all the `orphan` or `half-orphan` `loads`
 * Get all `highlights` (for a given set of `loads`)
 * Subscribe to various notifications (`anchors` created or removed, `highlights` created or removed, etc.)

## Processes and workflows

### Loading and configuration

 * The client code creates the `manager` object.
 * The client code loads and registers any wanted `document access strategies`, `selector creators`, `anchoring strategies` and `highlightter engines`. (Typically, these will be shipped in separate NPM modules.)

### Initialization

 * The client code tells the `manager` to init.
 * The `manager` chooses a `document access strategy`, going through the registered strategies, according to the configured priority.

### Describing a `segment` with `selectors`

 * The client code passes a `segment description` to the `manager`.
 * The `manager` will ask all registered `selector creators` about the `segment description`.
 * The `selector creators` will attempt to describe the `segment description` by `selectors`, relying on the data provided by the `document access strategy`.
 * When all registered `selector creators` have responded, the `manager` will compile a list of all the created `selectors`, and return it to the client code.

### Create an `anchor` based on an existing list of `selectors`

 * The client code passes the list of `selectors` to the `manager`, optionally together with a `load`.
 * The `manager` with consult with all the registered `anchoring strategies`, and ask each of them whether or not they can come up with an `anchor`. (It will try them according to their configured priority.)
 * If one of the `anchoring strategies` manages to come up with and `anchor`, and this `anchor` is returned to the client code.
 * Additionally, an attempt is made to immediately `realize` the newly created `anchor`.
 * If no `anchoring strategy` can create an `anchor`, then the `load` will be identified as an `orphan` (or a `half-orphan`, if an other `anchor` has successfully been created for the same `load` elsewhere.)

### Remove an `anchor`
 * TODO

### Page rendering

 * The `platform` renders a page.
 * The active `document access strategy` recognizes the event, does the necessary parsing, and notifies the `manager`.
 * The `manager` `realizes` the page.
 * `realizing` a `page` means that the `manager` tries to `realize` all the `anchors` intersecting with the given `page`.
 * `Realizing` an `anchor` means that we identify the `pages` which are now rendered, but for which no `highlight` exists, and we try to create those highlights.
 * The creation of a `highlight` is done by passing the `anchor` (and the required page index) to all the registered `highlight engines`, and asking them to render a highlight for it. (They are consulted according to their configured priority)
 * Depending on the result, the previously `virtual` or `partially real` `anchor` might become `real` or `partially real`, depending the existence and status of other pages intersecting with this anchor.

### Page un-rendering

 * The `platform` un-renders a page
 * The active `document access strategy` recognizes the event, and notifies the `manager`.
 * The `manager` `virtualizes` the page.
 * `Virtualizing` a `page` means that the `manager` tries to `virtualize` all the `anchors` intersecting with the given page.
 * `Virtualizing` an `anchor` for a given page means removing the corresponding `highlight` from the given `page`, and marking the `anchor` as `virtual` (or `partially real`, depending the existence of other pages intersecting with this anchor).

### Document content changes

 * The `platform` changes the content of the `docuemnt`
 * The active `document access strategy` recognizes the content changes, and notifies the `manager`.
 * The `manager` will go over the currently existing `anchors`, and try to `verify` them, using the `anchoring strategy` that originally created the given `anchor`.
 * The `manager` removes the `anchors` which were invalidated by the document content change, thus turning some `loads` into `orphans` (or `half-orphans`).
 * The `manager` will try to create all the missing `anchors` for the currently `orphan` or `half-orphan` `loads`.
