.include "via.inc"

GB_TMP=		$05

.segment "DRV"

		cli
		ldx	#0
nameloop:	jsr	getbyte
		beq	havename
		sta	name,x
		inx
		bne	nameloop
havename:	jsr	getbyte
		jmp	*-3

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
