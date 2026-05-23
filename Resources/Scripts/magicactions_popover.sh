#!/bin/zsh

MAGICACTIONS_EVENT_DIR="$HOME/Library/Application Scripts/local.elidev.MagicActions.FinderSync"
MAGICACTIONS_EVENT_FILE="$MAGICACTIONS_EVENT_DIR/popover-event.txt"

emit_popover() {
    /bin/mkdir -p "$MAGICACTIONS_EVENT_DIR"
    local tmp="$MAGICACTIONS_EVENT_FILE.$$"
    {
        print -r -- "$1"
        print -r -- "$2"
        print -r -- "$3"
        print -r -- "$4"
        /bin/date +%s
    } > "$tmp"
    /bin/mv "$tmp" "$MAGICACTIONS_EVENT_FILE"
}
