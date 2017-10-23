Utils = require('./utils')

# An operation on a string is a list of instructions.
# Take i: take the next i characters (i.e., leave them unchanged)
# Skip i: skip the next i characters (i.e., delete them)
# Insert s: insert the string s

# For example, [take 1, skip 1, take 1, insert "Z", take 1] applied to "abcd"
# yields        "a"     del "b" "c"     "Z"         "d"
# that is "acZd".

# The sum of of the take and skip lengths MUST equal the total length of the
# string applied to.

# Here is the "algebraic data type", represented as a pair:
# (Shame we aren't using Haskell -.-)
TAKE = 0
SKIP = 1
INSERT = 2
take = (i) -> [TAKE, i]
skip = (i) -> [SKIP, i]
insert = (i) -> [INSERT, i]

identity = (s) ->
    [take(s.length)]

isIdentity = (op) ->
  return op.length == 0 || (op.length == 1 && op[0][0] == TAKE)

# Takes a string and an operation (a list of instructions) and returns the
# result of applying them (as in the above example).
applyTextOp = (s, op) ->
    index = 0
    res = []
    for inst in op
        v = inst[1] # string or int depending on type
        switch inst[0]
            when TAKE
                res.push s[index ... index+v]
                index += v
            when SKIP
                index += v
            when INSERT
                res.push v
    return res.join ""

# Given two strings, return the instruction list that turns the first into the
# second. Does so by executing DP to find the longest common substring between
# the two. Then it uses take on those characters, skipping and inserting
# everything else.
# TODO figure out: do we actually need this?
text_diff2 = (text1, text2) ->
    dp = (([0, null] for i in [0..text2.length]) for j in [0..text1.length])

    mymax = (a, b) ->
        if a[0] > b[0] then a else b

    i = text1.length
    while i >= 0
        j = text2.length
        while j >= 0
            if i < text1.length
                dp[i][j] = mymax dp[i][j], [dp[i+1][j][0], 0]
            if j < text2.length
                dp[i][j] = mymax dp[i][j], [dp[i][j+1][0], 1]
            if i < text1.length and j < text2.length and text1[i] == text2[j]
                dp[i][j] = mymax dp[i][j], [dp[i+1][j+1][0] + 1, 2]
            j--
        i--
    
    ans = []
    i = 0; j = 0
    while i < text1.length and j < text2.length
        # Assume the next three instructions are
        # take a1, skip a2, insert a3
        # Compute a1, a2, a3, then add the non-trivial ones to ans.
        a1 = 0; a2 = 0; a3 = ""
        while dp[i][j] and dp[i][j][1] == 2
            a1++; i++; j++
        while dp[i][j] and dp[i][j][1] != 2
            if dp[i][j][1] == 0
                a2++; i++
            else
                a3 += text2[j]; j++
        if a1 > 0 then ans.push take a1
        if a2 > 0 then ans.push skip a2
        if a3 != "" then ans.push insert a3

    return ans

# This is a helper function for below. The idea is that we are trying to build
# a lists of instructions. This takes a lists, and an instruction to add
# (or null). It also merges consecutive instructions of the same type.
# It also ensures that when 'skip' and 'insert' are consecutive, the skip is
# always first.
# Mutuates its input.
appendInst = (l, i) ->
    if l.length > 0 and l[l.length-1][0] == i[0]
        l[l.length-1][1] += i[1]
    else if l.length > 0 and l[l.length-1][0] == INSERT and i[0] == SKIP
        if l.length > 1 and l[l.length-2][0] == SKIP
            l[l.length-2][1] += i[1]
        else
            l.push(l[l.length-1])
            l[l.length-2] = i
    else
        l.push i

# Returns [m1, m2] such that l1 o m1 = l2 o m2
# Base state s is an argument but currently ignored.
xformText = (s, l1, l2) ->
    # Copy the lists, because we are going to mutate them.
    l1 = ([a,b] for [a,b] in l1)
    l2 = ([a,b] for [a,b] in l2)

    # Indices which track our current position in the list:
    i1 = 0
    i2 = 0

    # The result lists that we are going to build
    m1 = []
    m2 = []

    while i1 < l1.length or i2 < l2.length
        # If there are two INSERTs at the same spot, the one from the left 
        # operation (that is, l1) goes first. This is an arbitrary decision,
        # but we must be consistent.
        if i1 < l1.length and l1[i1][0] == INSERT
            s = l1[i1][1]
            appendInst m1, take s.length
            appendInst m2, insert s
            i1++

        else if i2 < l2.length and l2[i2][0] == INSERT
            s = l2[i2][1]
            appendInst m1, insert s
            appendInst m2, take s.length
            i2++

        else
            # Now, i1 and i2 each point to a Take or a Skip.
            # (By the invariant, the sums of lengths should always match, we
            # cannot have a Take or a Skip if the other is empty.)
            amt = Math.min l1[i1][1], l2[i2][1]
            if l1[i1][0] == TAKE
                appendInst m1, (if l2[i2][0] == SKIP then skip else take) amt
            if l2[i2][0] == TAKE
                appendInst m2, (if l1[i1][0] == SKIP then skip else take) amt

            if l1[i1][1] == amt then i1++
            else l1[i1][1] -= amt
            if l2[i2][1] == amt then i2++
            else l2[i2][1] -= amt

    return [m2, m1]

xformRange = (s, op, range) ->
    [start, end] = range
    i = 0
    pos = 0
    while i < op.length
        if op[i][0] == TAKE
            pos += op[i][1]
            i++
        else
            delCount = 0
            insCount = 0
            if op[i][0] == SKIP
                delCount = op[i][1]
                i++
            if i < op.length && op[i][0] == INSERT
                insCount = op[i][1].length
                i++

            spliceStart = pos
            spliceEnd = pos + delCount

            if spliceStart <= start && spliceEnd >= end
                start = spliceStart
                end = spliceStart
            else if spliceEnd <= start
                start += insCount - delCount
                end += insCount - delCount
            else if spliceStart >= end
                break
            else if spliceStart >= start && spliceEnd <= end
                end += insCount - delCount
            else if spliceEnd < end
                start = spliceStart + insCount
                end += insCount - delCount
            else
                end = spliceEnd

            pos += insCount
    return [start, end]

# Compose the two operations, returning l1 o l2
composeText = (s, l1, l2) ->
    # Copy the lists, because we are going to mutate them.
    l1 = ([a,b] for [a,b] in l1)
    l2 = ([a,b] for [a,b] in l2)

    # Indices which track our current position in the list:
    i1 = 0
    i2 = 0

    # The result list that we are going to build
    m = []

    while i2 < l2.length or i1 < l1.length
        if i1 < l1.length and l1[i1][0] == SKIP
            appendInst m, skip l1[i1][1]
            i1++
        else
            type2 = l2[i2][0]
            if type2 == INSERT
                appendInst m, insert l2[i2][1]
                i2++
            else if type2 == TAKE
                type1 = l1[i1][0]
                if type1 == TAKE
                    amt = Math.min l1[i1][1], l2[i2][1]
                    appendInst m, take amt

                    if l1[i1][1] == amt then i1++
                    else l1[i1][1] -= amt
                    if l2[i2][1] == amt then i2++
                    else l2[i2][1] -= amt
                else # INSERT
                    amt = Math.min l1[i1][1].length, l2[i2][1]
                    appendInst m, insert l1[i1][1][0 ... amt]

                    if l1[i1][1].length == amt then i1++
                    else l1[i1][1] = l1[i1][1][amt ... ]
                    if l2[i2][1] == amt then i2++
                    else l2[i2][1] -= amt
            else if type2 == SKIP
                type1 = l1[i1][0]
                if type1 == TAKE
                    amt = Math.min l1[i1][1], l2[i2][1]
                    appendInst m, skip amt

                    if l1[i1][1] == amt then i1++
                    else l1[i1][1] -= amt
                    if l2[i2][1] == amt then i2++
                    else l2[i2][1] -= amt
                else # INSERT
                    amt = Math.min l1[i1][1].length, l2[i2][1]
                    # Don't add an op, gets cancelled out

                    if l1[i1][1].length == amt then i1++
                    else l1[i1][1] = l1[i1][1][amt ... ]
                    if l2[i2][1] == amt then i2++
                    else l2[i2][1] -= amt

    return m

inverseText = (base, l) ->
    m = []
    pos = 0
    for [type, val] in l
        if type == TAKE
            appendInst m, take(val)
            pos += val
        else if type == SKIP
            deletedText = base.substring(pos, pos + val)
            appendInst m, insert(deletedText)
            pos += val
        else if type == INSERT
            appendInst m, skip(val.length)
    return m

toString = (op) ->
    opToString = (o) ->
        switch o[0]
            when TAKE
                "take #{o[1]}"
            when SKIP
                "skip #{o[1]}"
            when INSERT
                "insert #{o[1]}"
    "[#{(opToString o for o in op).join ", "}]"

canonicalized = (op) ->
    ans = []
    for [type, val] in op
        if val # positive integer or non-empty string
            appendInst ans, [type,val]
    return ans

# Returns an "index map" for the op
# e.g. if the second character of a string becomes the fourth character
# after an op is applied, the returned map will map 2 -> 4
# (if the second character is deleted, 2 will not be in the map)
getIndexMapForTextOp = (op) ->
    res = {}
    srcPos = 0
    dstPos = 0
    for [type, val] in op
        if type == TAKE
            for i in [0 .. val - 1]
                res[srcPos + i] = dstPos + i
            srcPos += val
            dstPos += val
        else if type == SKIP
            srcPos += val
        else if type == INSERT
            dstPos += val.length
        else
            Utils.assert "bad op type"
    return res

# Returns a text op that does a splice at the given `index`, removing
# `numToDelete` characters and inserting the `toInsert` string
opTextSplice = (totalLen, index, toInsert, numToDelete) ->
    canonicalized [take(index), skip(numToDelete), insert(toInsert), take(totalLen-index-numToDelete)]

# Asserts that the op is valid and applies to the given string.
# Returns the length of the resulting string after application.
assertValidTextOp = (s, op) ->
    oldLength = 0
    newLength = 0
    prevType = -1
    for o in op
        Utils.assert(o[0] == TAKE or o[0] == SKIP or o[0] == INSERT)
        switch o[0]
            when TAKE
                Utils.assert(Utils.isInteger(o[1]) and o[1] >= 1)
                oldLength += o[1]
                newLength += o[1]
            when SKIP
                Utils.assert(Utils.isInteger(o[1]) and o[1] >= 1)
                oldLength += o[1]
            when INSERT
                Utils.assert(typeof(o[1]) == 'string' and o[1].length >= 1)
                newLength += o[1].length
        if prevType != -1
            curType = o[0]
            Utils.assert((prevType == TAKE and curType != TAKE) or
                         (prevType == SKIP and curType != SKIP) or
                         (prevType == INSERT and curType == TAKE))
        prevType = o[0]
    Utils.assert(oldLength == s.length)
    return newLength

# Export stuff

module.exports.take = take
module.exports.skip = skip
module.exports.insert = insert
module.exports.applyTextOp = applyTextOp
module.exports.xformText = xformText
module.exports.composeText = composeText
module.exports.toString = toString
module.exports.canonicalized = canonicalized
module.exports.getIndexMapForTextOp = getIndexMapForTextOp
module.exports.opTextSplice = opTextSplice
module.exports.identity = identity
module.exports.isIdentity = isIdentity
module.exports.inverseText = inverseText
module.exports.assertValidTextOp = assertValidTextOp
module.exports.xformRange = xformRange
