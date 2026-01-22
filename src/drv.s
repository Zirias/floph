.include "via.inc"

GB_TMP=		$05
DIR_TMP0=	$10

.segment "DRV"

		cli
start:		ldx	#0
nameloop:	jsr	getbyte
		beq	havename
		sta	name,x
		inx
		bne	nameloop
havename:	lda	#$a0
		sta	name,x
		inx
		cpx	#$10
		bcc	lenok
		ldx	#$10
lenok:		stx	DIR_TMP0
		lda	#18
		sta	$6
		lda	#1
		sta	$7
readdir:	lda	#$80
		sta	$0
		lda	#$02
		sta	checkfile+1
		lda	#$05
		sta	checkname+1
		lda	$0
		bmi	*-2
checkfile:	lda	$302
		tax
		and	#$3
		beq	checknext
		txa
		eor	#$80
		and	#$fc
		bne	checknext
		tax
checkname:	lda	$305,x
		cmp	name,x
		bne	checknext
		inx
		cpx	DIR_TMP0
		bne	checkname
		ldx	checkfile+1
		inx
		stx	ldsttrack+1
		inx
		stx	ldstsect+1
ldstsect:	lda	$3ff
		sta	$301
ldsttrack:	lda	$3ff
		sta	$300
		bne	found
checknext:	clc
		lda	checkfile+1
		adc	#$20
		sta	checkfile+1
		clc
		lda	checkname+1
		adc	#$20
		sta	checkname+1
		bcc	checkfile
		lda	$301
		sta	$7
		lda	$300
		sta	$6
		bne	readdir

		; error
		jmp	start

found:		jmp	*

getbyte:	sty	gb_ry+1
		ldy	#8
gb_loop:	lda	#$85
		and	VIA1_PRB
		bmi	exit
		beq	gb_loop
		lsr	a
		lda	#$02
		bcc	gb_skip
		lda	#$08
gb_skip:	sta	VIA1_PRB
		ror	GB_TMP
gb_wait:	lda	VIA1_PRB
		and	#$05
		eor	#$05
		beq	gb_wait
		lda	#0
		sta	VIA1_PRB
		dey
		bne	gb_loop
gb_ry:		ldy	#$ff
		lda	GB_TMP
		rts

exit:		pla
		pla
		rts

name:		.res	$11
