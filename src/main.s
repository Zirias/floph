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
		jsr	floppy_hashfile
recvloop:	jsr	floppy_receive
		bcc	recvloop
		ldx	floppy_result
		cpx	#8
		beq	outloop
		rts
outloop:	lda	floppy_result,x
		lsr
		lsr
		lsr
		lsr
		ora	#$30
		cmp	#$3a
		bcc	outh
		adc	#6
outh:		jsr	$ffd2
		lda	floppy_result,x
		and	#$f
		ora	#$30
		cmp	#$3a
		bcc	outl
		adc	#6
outl:		jsr	$ffd2
		dex
		bne	outloop
		lda	#$d
		jmp	$ffd2
