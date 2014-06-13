# dom-anchor-core

Core library code for a DOM Anchoring Framework

## Conceptual overview

This document is the short description of how the anchoring framework works.

### Passive components

#### Document

The document we are working with, in the current session.

In theory, we could work over any kind of document, but in practice, aside for the core itself, there are some modules which are tied to the DOM.

Currently supported document types are
 * Generic HTML documents
 * PDF documents rendered using PDF.js

Later we plan to support scribd, and google docs, ans several others formats, too.

#### Page

A `page` is a piece of the document which is rendered at the same time. 

A simple HTML document is simply handled as a one-page document.

Many other document formats / platforms use lazy rendering, which means that they only render a few pages at a time, and the rest is only rendered on demand, when the user needs to see them. (This practice is useful for conserving memory and CPU resources.)

Our system needs to know about which pages are rendered, and which are not, so that we can react properly.

#### Segment

Any data describing any part of any document.

 * In many cases, this is the part of the document *itself*, and not an abstract description of it.
 * All selectors carry a `type` field, for easy recognition.
 * Typically uses DOM objects or similar references.
 * Does not have to be serializable.
 * Examples:
   * a browser native [Range](https://developer.mozilla.org/en-US/docs/Web/API/range) object, describing a part of the document the user has selected.
   * a [NormalizedRange](https://github.com/openannotation/annotator/blob/bd008609441138b162928e69541d76f6fcd45c1a/src/range.coffee#L159) object, as used in [Annotator](https://github.com/openannotation/annotator), describing the same.

#### Selector

A piece of information trying to describe a `segment`. See also the definition [in the Open Annotation Data Model](http://www.openannotation.org/spec/core/specific.html#Selectors).

 * Is created by `Selector creators`
 * Must be serializable, so no DOM object references (or similar) are allowed here
 * Do not have to be all-encompassing; it's permissible to conveys only partial information, too.
 * All selectors have a `type` field

#### Anchor

A piece of information representing the results of a previous attempt to identify a segment of the document

 * Is created by an `Anchoring strategy`
 * Might or might not be serializable
 * Can use DOM objects, etc
 * Can also store extra information about how the current content of the document compares to the state captured in the selectors
 * Different kinds of anchors can encapsulate different informatino to identify a given segment.
 * All anchors have a `type` field.

#### Highlight

Visual representation of an anchor in the DOM

 * Is rendered by a `Highlighter engine`
 * Lives in the DOM
 * Visible to the user
 * Are active objects, and can indicate some state changes, and can interact with the user.

### Active components

#### Platform

This part is not actually part of our system, but we must know about it.
If we are not working with a static HTML document, but with an application displaying a given document type, then we call this application the `Platform`. An example is the PDF.js platform, which we support for PDF documents.

The platform interacts with, and is handled by the `Document Access Strategy`.

#### Document accesss strategy

#### Selector Creator

Responsible for describing a `segment` with [a set of] `selectors`.

 * Input: a `Segment`
 * Output: zero or more `Selectors`
 * Typically, the manager works with many selector creators loaded simultaneously, each responsible only for describing a given type of segment with a given type of selector.
 * It's also allowed to respond with a promise, which will be resolved with a list of selectors later.

#### Anchoring strategy

Responsible for identifying `segments` of the `document`.

 * Input:
   * a list of `selectors` describing the `segment`
   * the data extracted from the `document` by the current `document access strategy`
 * Output: an `anchor`
 * Can also respond with a promise, which will be resolved with an `anchor` later.
 * Typically, the `manager` works with several `anchoring strategies` loaded simultaneously, each responsible only for identifing the `segment` using a given method. It's perfectly OK to fail, if the the `selctors` required by the given method are unavailable, or if the data stored in the received `selectors` does not match with the data provided by the `document access strategy`.
 * TODO: verification, etc

#### Highlighter engine

Responsible for creating the highlights

 * Input: an `anchor`
 * Output: a `highlight`
 * Several `highlighter engines` can be loaded at the same time; typically, each is only reaponsible for handling a given type of `anchor`, and might be restricted to work with a given set of `platforms`.
 * The rendering of the highlights can be an asynchronous process.
 * The generated highlight objects must implement the standard Highlight interface.

#### Anchor Manager

 * TODO: describe

## Processes and workflow

The manager can use many selector creators simultaneously.
If a segment needs to be described, the manager will ask all registered selector creators.


When all registered selector creators have responded, the 
