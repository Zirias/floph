.include "statuscode.inc"
.include "via.inc"

GB_TMP=		$05
DIR_TMP0=	$10

CSR_0=		0
CSR_1=		1
TRACK_0=	6
TRACK_1=	8
SECT_0=		7
SECT_1=		9
BUF_0=		3
BUF_1=		4

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
		ldx	#1
readdir:	jsr	startread
		lda	#$02
		sta	checkfile+1
		lda	#$05
		sta	checkname+1
		jsr	completeread
		bcs	checkfile
		lda	#ST_READERR
		jsr	senderror
		jmp	start
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
		ldx	$301
		lda	$300
		bne	readdir
		lda	#ST_NOTFOUND
		jsr	senderror
		jmp	start

found:		lda	#2
		jsr	sendbyte
		lda	$300
		jsr	sendbyte
		lda	$301
		jsr	sendfinalbyte
		jmp	start

startread:
sr_track:	sta	TRACK_0
sr_sect:	stx	SECT_0
		lda	#$80
sr_csr:		sta	CSR_0
		rts

completeread:
		ldy	#5
cr_csr_0:	lda	CSR_0
		bmi	cr_csr_0
		cmp	#1
		beq	cr_done
		sei
		lda	$16
		sta	$12
		lda	$17
		sta	$13
		dey
		cli
		beq	cr_fail
		lda	#$80
cr_csr_1:	sta	CSR_0
		bmi	cr_csr_0
cr_fail:	clc
cr_done:	rts

senderror:
		tax
		lda	#1
		jsr	sendbyte
		txa
sendfinalbyte:
		jsr	sendbyte
		lda	#0

sendbyte:	sta	GB_TMP
		ldy	#8
sb_loop:	lda	VIA1_PRB
		and	#$5
		bne	sb_loop
		lsr	GB_TMP
		lda	VIA1_PRB
		and	#$f5
		ora	#$8
		bcc	sb_zerobit
		eor	#$a
sb_zerobit:	sta	VIA1_PRB
sb_waitack:	lda	VIA1_PRB
		and	#$5
		eor	#$5
		bne	sb_waitack
		lda	VIA1_PRB
		and	#$f5
		sta	VIA1_PRB
		dey
		bne	sb_loop
		rts

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
