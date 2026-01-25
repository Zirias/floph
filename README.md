# floph - the Floppy Hasher

This is a C64 tool to hash files directly on the 1541 floppy, using 64 bit
FNV-1a.

It can hash any regular, non-locked and not opened file of type `PRG`,
`SEQ` or `USR`. It currently doesn't support hashing a whole disk, which
might be added later.

The interface is currently a simple TUI allowing to select a file to hash.
There are no features like progress display, avoiding repeated hashing,
gracefully handling read errors etc yet.

Also, the drive number is currently hardcoded to #8, some later version should
introduce a drive selection.

