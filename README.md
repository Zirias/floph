# floph - the Floppy Hasher

This is a C64 tool to hash files directly on the 1541 floppy, using 64 bit
FNV-1a.

It can hash any regular, non-locked and not opened file of type `PRG`,
`SEQ` or `USR`. It currently doesn't support hashing a whole disk, which
might be added later.

Floph features a TUI to select a file to hash, also handling possible errors
and displaying a progress bar while hashing. Correctness of the progress
depends on correct block size information in the directory.

It also detects available drives on startup and, if there's more than one
connected, shows a little menu to pick which drive to use.

So far, there's no feature to persist the calculated hashes.
