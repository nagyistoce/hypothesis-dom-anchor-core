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

# Export Util object
module.exports = Util
