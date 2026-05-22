#!/bin/zsh

MAGICRIGHT_EVENT_DIR="$HOME/Library/Application Scripts/local.elidev.MagicRight.FinderSync"
MAGICRIGHT_EVENT_FILE="$MAGICRIGHT_EVENT_DIR/popover-event.txt"

emit_popover() {
    /bin/mkdir -p "$MAGICRIGHT_EVENT_DIR"
    local tmp="$MAGICRIGHT_EVENT_FILE.$$"
    {
        print -r -- "$1"
        print -r -- "$2"
        print -r -- "$3"
        print -r -- "$4"
        /bin/date +%s
    } > "$tmp"
    /bin/mv "$tmp" "$MAGICRIGHT_EVENT_FILE"
}
