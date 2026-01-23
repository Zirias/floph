# floph - the Floppy Hasher

This is a C64 tool to hash files directly on the 1541 floppy, using 64 bit
FNV-1a.

It can hash any regular, non-locked and not opened file of type `PRG`,
`SEQ` or `USR`. It currently doesn't support hashing a whole disk, which
might be added later.

The interface is currently a simple CLI requiring to enter the exact name of
the file to hash. Later versions might add a menu-driven TUI instead.

Also, the drive number is currently hardcoded to #8, some later version should
introduce a drive selection.

