Promise = require('es6-promise').Promise

Util = {}

# Public: Flatten a nested array structure
#
# Returns an array
Util.flatten = (array) ->
  flatten = (ary) ->
    flat = []

    for el in ary
      flat = flat.concat(if el and Array.isArray(el) then flatten(el) else el)

    return flat

  flatten(array)

# Public: attempt to do something on elements of a list
# until the first attempt succeeds
Util.searchUntilFirst = (list, test) ->
  unless list?
    throw new Error "Can't search in a null list!"

  unless test?
    throw new Error "Got a null test!"

  # Create a wrapper promise
  new Promise (found, searchFailed) ->
    list.reduce((sequence, elem) ->
      sequence.then ->
        new Promise (resolve, reject) ->
          test(elem).then (result) ->
            reject # Break the cycle. We have a solution
              type: "we are good"
              elem: elem
              data: result
          , ->
            resolve() # Continue with the search
    , Promise.resolve())
    .then ->
      # The whole sequence was executed. This means there was no match.
      searchFailed "all elements failed the test"
    , (match) ->
      # Look like we got a match, or an error.
      # Have we intentionally stopped the search?
      if match?.type is "we are good"
        # Yes, we have. So this really is a match
        delete match.type
        found match # Actually return the match
      else
        # No, not a match. This is an error.
        searchFailed match

# A very simple set implementation
class Util.ArraySet extends Array

  # Add this new element, if it's not already a member.
  add: (element) ->
    @push element unless element in this

  # Remove this element, it it's a member
  remove: (element) ->
    index = @indexOf element
    unless index is -1
      this[index..index] = []
    null

# Export Util object
module.exports = Util
