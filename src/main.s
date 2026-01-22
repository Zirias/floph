.include "floppy.inc"

.segment "BHDR"

		.word	$0801
		.word	hdrend
		.word	2026
		.byte	$9e, "2061", 0
hdrend:		.word	0

.data

filename:	.byte	"floph", 0

.segment "ENTRY"

entry:		lda	#8
		jsr	floppy_init
		lda	#<filename
		ldx	#>filename
		jmp	floppy_hashfile
