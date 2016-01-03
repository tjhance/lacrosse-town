# Find matches for a given string

fs = require 'fs'

words = null

exports.init = (callback) ->
    simplify = (word) ->
        # TODO should strip other characters like spaces
        word.toLowerCase()

    fs.readFile 'dictionaries/UKACD-normalized.txt', 'utf8', (err, data) ->
        if err
            console.error err
        else
            # the licensing information of the dictionary is above this line
            # so we cut it off
            spl = data.split('--------------------------------------------------------------------\n')
            if spl.length != 2
                console.error 'error parsing dictionary'
            else
                data = spl[1]

                # now 'data' is just a newline-separated list of words
                words = (simplify word for word in data.split('\n') when word != '')

                callback()

# pattern should be a mix of lower-case letters and periods
findMatches = (pattern) ->
    regex = new RegExp('^' + pattern + '$')
    result = []
    for word in words
        if word.match(regex)
            result.push(word)
    return result

validatePattern = (pattern) ->
    if typeof(pattern) != 'string'
        return false

    if not (pattern.length > 0 and pattern.length < 200)
        return false

    for i in [0 .. pattern.length - 1]
        c = pattern.charAt(i)
        if not (c == '.' or (c >= 'a' and c <= 'z'))
            return false

    return true

# HTTP request handler for /find-matches
# Takes 'pattern' as a query param. 'pattern' is a pattern like '..a...'
# Returns a JSON object
# {
#    matches: [ ... all matches ... ]
# }
exports.handle = (req, res) ->
    pattern = req.body['pattern']

    if not validatePattern(pattern)
        res.statusCode = 400
        res.send('invalid pattern')
        return

    res.send({matches: findMatches(pattern)})
