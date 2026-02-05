# floph - the Floppy Hasher

This is a C64 tool to hash files directly on the 1541 floppy, using 64 bit
FNV-1a.

## Features

* Hash any regular, non-locked and not opened file of type `PRG`, `SEQ` or
  `USR`.
* Hash a whole disk (currently only standard 35 tracks).
* Detect and identify available drives on startup.
* May run on any 1541, 1570 or 1571.
* A simple TUI allows to select a file or the whole disk using cursor keys
  and start hashing with `<RETURN>`.
* Clean exit is always possible with `<RUN/STOP>`.
* Show a progress bar while hashing. For files, this can only be correct if
  the number of blocks in the directory was correct.

Hashing a whole disk uses a fixed sector interleave of 11. In this mode, most
errors are tolerated, if they occur, the error code is hashed instead of the
sector contents. This should allow to correctly hash disks that e.g. use
errors for copy protection purposes.

After detection and identification of connected drives, a little menu is
shown, allowing to pick any supported drive, or cancel and exit without
uploading and starting floph's drive code.

## Screenshots

<a href="https://github.com/Zirias/floph/blob/res/floph_00.png?raw=true"><img
    src="https://github.com/Zirias/floph/blob/res/floph_00.png?raw=true"
    width="202px"></a>
<a href="https://github.com/Zirias/floph/blob/res/floph_01.png?raw=true"><img
    src="https://github.com/Zirias/floph/blob/res/floph_01.png?raw=true"
    width="202px"></a>
<a href="https://github.com/Zirias/floph/blob/res/floph_02.png?raw=true"><img
    src="https://github.com/Zirias/floph/blob/res/floph_02.png?raw=true"
    width="202px"></a>
<a href="https://github.com/Zirias/floph/blob/res/floph_03.png?raw=true"><img
    src="https://github.com/Zirias/floph/blob/res/floph_03.png?raw=true"
    width="202px"></a>
<a href="https://github.com/Zirias/floph/blob/res/floph_04.png?raw=true"><img
    src="https://github.com/Zirias/floph/blob/res/floph_04.png?raw=true"
    width="202px"></a>

## Missing (future) features

Here's a rough list of what to possibly add later:

* Configurable number of tracks for whole-disk hashing, to allow 40- and
  42-track disks.
* Persist a pre-calculated whole-disk hash in some unused area of the BAM,
  allowing an automatic verify later.
* For file hashes, maybe persist them in some regular (`SEQ`?) file.

## pfloph, the "PC Floppy Hasher"

Included with floph comes a little C program allowing to calculate the same
hashes of plain files or `d64` disk images on the PC command line.

Usage:

    pfloph [-d] [file]

* `-d`: Select "disk mode", input is expected to be a `d64` image.
* `file`: The file to hash, if omitted, it is expected on standard input to
  allow usage with pipes.

## Building

Build requirements:

* GNU make
* A C compiler (for pfloph)
* `cc65`
* `c1541` from vice (for creating test disks)

To build `floph.prg` and `pfloph`, just type

    make

A disk image for testing (with lots of files added) can be created with

    make disk

For the same disk, but containing a single sector error, type

    make errdisk


