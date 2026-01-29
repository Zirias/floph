.include "fnv1a.inc"
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

RQTRACK=	$35
CURTRACK=	$37
SECTORS=	$3b
SECTNO=		$3c

.segment "DRV"

		lda	VIA2_PRB
		ora	#8
		sta	VIA2_PRB
		lda	#18
		ldx	#0
		jsr	startread
		jsr	completeread
		bcs	bamok
		lda	#ST_READERR
		jsr	senderror
		rts
bamok:		lda	#$17
		jsr	sendbyte
		ldx	#0
disknameloop:	lda	$390,x
		jsr	sendbyte
		inx
		cpx	#$17
		bne	disknameloop
		lda	#18
		ldx	#1
dirsectloop:	jsr	startread
		jsr	completeread
		bcs	dirsectok
		lda	#ST_READERR
		jsr	senderror
		rts
dirsectok:	ldx	#2
dirsendloop:	lda	#21
		jsr	sendbyte
dirinnerloop:	lda	$300,x
		jsr	sendbyte
		inx
		txa
		and	#$1f
		cmp	#$15
		bcc	dirinnerloop
		txa
		adc	#8
		tax
		lda	$300,x
		jsr	sendbyte
		inx
		lda	$300,x
		jsr	sendbyte
		inx
		beq	dirnextsect
		inx
		inx
		bne	dirsendloop
dirnextsect:	ldx	$301
		lda	$300
		bne	dirsectloop
		lda	#0
		jsr	sendbyte

cmdloop:	lda	VIA2_PRB
		and	#$f7
		sta	VIA2_PRB
		lda	#CSR_0
		sta	sr_csr+1
		sta	cr_csr_0+1
		sta	cr_csr_1+1
		ldx	#TRACK_0
		stx	sr_track+1
		inx
		stx	sr_sect+1
		lda	#BUF_0
		sta	hl_nexttrack+2
		sta	hl_nextsect+2
		jsr	getbyte
		sta	RQTRACK
		tay
		bne	trackok
		iny
		sty	CURTRACK
		jsr	getbyte		; ignored for now
		lda	#20
		sta	SECTORS
		sta	sectinit+1
		sta	subsects+1
		lda	#0
		sta	SECTNO
		beq	starthashing
trackok:	jsr	getbyte
starthashing:	tax
		lda	VIA2_PRB
		ora	#8
		sta	VIA2_PRB
		tya
		jsr	startread
		jsr	fnv1a_init
		jsr	completeread
		bcs	hashloop
		jmp	readerr
hashloop:	lda	RQTRACK
		bne	hl_nextsect
		dec	SECTORS
		bpl	disk_nextsect
		ldy	CURTRACK
		iny
		cpy	#18
		bne	disk_skip0
		sty	sectinit+1
		sty	subsects+1
disk_skip0:	cpy	#25
		bne	disk_skip1
		lda	#17
		sta	sectinit+1
		sta	subsects+1
disk_skip1:	cpy	#31
		bne	disk_skip2
		lda	#16
		sta	sectinit+1
		sta	subsects+1
disk_skip2:	cpy	#36
		bne	disk_skip3
		ldy	#0
		ldx	#0
		beq	hf_call
disk_skip3:	sty	CURTRACK
sectinit:	lda	#$ff
		sta	SECTORS
		beq	hashsector
disk_nextsect:	clc
		lda	SECTNO
		adc	#11
		sta	SECTNO
subsects:	sbc	#$ff
		bcc	dns_ok
		sta	SECTNO
dns_ok:		ldx	SECTNO
		ldy	CURTRACK
		bne	hashsector
hl_nextsect:	ldx	$301
hl_nexttrack:	ldy	$300
		beq	hashfinal
hashsector:	lda	sr_csr+1
		eor	#1
		sta	sr_csr+1
		sta	cr_csr_0+1
		sta	cr_csr_1+1
		lda	sr_track+1
		eor	#$e
		sta	sr_track+1
		ora	#1
		sta	sr_sect+1
		lda	hl_nexttrack+2
		eor	#7
		sta	hl_nexttrack+2
		sta	hl_nextsect+2
		tya
		jsr	startread
		ldx	#0
		ldy	RQTRACK
		bne	hs_file
		lda	$18
		cmp	#18
		bne	hs_call
		lda	$19
		bne	hs_call
		ldy	#$f0
		bne	hs_call
hs_file:	ldy	#254
		ldx	#2
hs_call:	lda	hl_nexttrack+2
		eor	#7
		jsr	fnv1a_hashbuf
		tya
		jsr	sendbyte
		jsr	completeread
		bcc	readerr
		jmp	hashloop
hashfinal:	dex
		txa
		tay
		ldx	#2
hf_call:	lda	hl_nexttrack+2
		jsr	fnv1a_hashbuf
		lda	#8
		jsr	sendbyte
		ldx	#0
sendhash:	lda	fnv1a_hash,x
		jsr	sendbyte
		inx
		cpx	#8
		bne	sendhash
		jmp	cmdloop
readerr:	ldy	RQTRACK
		bne	reporterr
		cmp	#3
		beq	reporterr
		cmp	#$f
		beq	reporterr
		sta	fnv1a_hashbyte
		jmp	hashloop
reporterr:	lda	#ST_READERR
		jsr	senderror
		jmp	cmdloop

startread:
sr_track:	sta	TRACK_0
sr_sect:	stx	SECT_0
		lda	#$80
sr_csr:		sta	CSR_0
		rts

completeread:
		ldy	#6
cr_csr_0:	lda	CSR_0
		bmi	cr_csr_0
		cmp	#1
		beq	cr_done
		dey
		beq	cr_fail
		sei
		lda	$16
		sta	$12
		lda	$17
		sta	$13
		cli
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

sendbyte:	sta	GB_TMP
		ldy	#8
sb_loop:	lda	VIA1_PRB
		and	#$5
		bne	sb_loop
		lsr	GB_TMP
		lda	#$8
		bcc	sb_zerobit
		eor	#$a
sb_zerobit:	sta	VIA1_PRB
sb_waitack:	lda	VIA1_PRB
		and	#$5
		eor	#$5
		bne	sb_waitack
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
