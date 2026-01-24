.include "floppy.inc"
.include "kernal.inc"
.include "tui.inc"

.segment "BHDR"

		.word	$0801
		.word	hdrend
		.word	2026
		.byte	$9e, "2061", 0
hdrend:		.word	0

.data

uploaderrtxt:	.byte	"error uploading drive code!", $d, 0

.segment "ENTRY"

entry:		lda	#8
		jsr	floppy_init
		bcc	displaydir
		ldy	#0
uploaderr:	lda	uploaderrtxt,y
		bne	uecout
		rts
uecout:		jsr	KRNL_CHROUT
		iny
		bne	uploaderr
displaydir:	jsr	floppy_readdir
		jmp	tui_run
