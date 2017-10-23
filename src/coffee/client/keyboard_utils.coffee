# on macs, we use Cmd, for everything else, we use Ctrl

parser = null

usesCmd = () ->
    if not parser
        parser = new UAParser()
    return parser.getOS().name == 'Mac OS'

getMetaKeyName = () ->
    if usesCmd()
        return "CMD"
    else
        return "CTRL"

module.exports.usesCmd = usesCmd
module.exports.getMetaKeyName = getMetaKeyName
