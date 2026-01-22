.include "floppy.inc"
.include "kernal.inc"

.segment "BHDR"

		.word	$0801
		.word	hdrend
		.word	2026
		.byte	$9e, "2061", 0
hdrend:		.word	0

.data

prompt:		.byte	$d, "enter full file name to hash,", $d, "empty to exit", $d
		.byte	"file: ", 0
hashtxt:	.byte	"hash: ", 0
readerrtxt:	.byte	"read error!", $d, 0
notfoundtxt:	.byte	"not found!", $d, 0

.bss

filename:	.res	$80

.segment "ENTRY"

entry:		lda	#8
		jsr	floppy_init

mainloop:	ldy	#0
promptout:	lda	prompt,y
		beq	promptdone
		jsr	KRNL_CHROUT
		iny
		bne	promptout
promptdone:	ldy	#0
namein:		jsr	KRNL_CHRIN
		cmp	#$d
		beq	havename
		sta	filename,y
		iny
		bne	namein
havename:	lda	#0
		sta	filename,y
		lda	#$d
		jsr	KRNL_CHROUT
		lda	filename
		bne	sendname
		rts
sendname:	lda	#<filename
		ldx	#>filename
		jsr	floppy_hashfile
recvloop:	jsr	floppy_receive
		bcc	recvloop
		lda	floppy_result
		cmp	#8
		beq	hashout
		ldy	#0
		bit	floppy_result+1
		bmi	notfoundout
		bvs	readerrout
		rts
notfoundout:	lda	notfoundtxt,y
		beq	mainloop
		jsr	KRNL_CHROUT
		iny
		bne	notfoundout
readerrout:	lda	readerrtxt,y
		beq	mainloop
		jsr	KRNL_CHROUT
		iny
		bne	readerrout
hashout:	ldy	#0
hashtxtout:	lda	hashtxt,y
		beq	hashvalout
		jsr	KRNL_CHROUT
		iny
		bne	hashtxtout
hashvalout:	ldx	floppy_result
outloop:	lda	floppy_result,x
		lsr
		lsr
		lsr
		lsr
		ora	#$30
		cmp	#$3a
		bcc	outh
		adc	#6
outh:		jsr	KRNL_CHROUT
		lda	floppy_result,x
		and	#$f
		ora	#$30
		cmp	#$3a
		bcc	outl
		adc	#6
outl:		jsr	KRNL_CHROUT
		dex
		bne	outloop
		lda	#$d
		jsr	KRNL_CHROUT
		jmp	mainloop
