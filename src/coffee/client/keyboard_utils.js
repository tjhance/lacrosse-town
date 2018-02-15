// on macs, we use Cmd, for everything else, we use Ctrl

let parser = null;

export function usesCmd() {
  if (!parser) {
    parser = new UAParser();
  }
  return parser.getOS().name === 'Mac OS';
}

export function getMetaKeyName() {
  if (usesCmd()) {
    return "CMD";
  } else {
    return "CTRL";
  }
}
