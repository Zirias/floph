.include "cia.inc"
.include "drv.inc"
.include "kernal.inc"
.include "statuscode.inc"
.include "zpshared.inc"

.export floppy_detect
.export floppy_init
.export floppy_readdir
.export floppy_showdir
.export floppy_hashdisk
.export floppy_hashfile
.export floppy_receive

.export floppy_result
.export dirptr_l
.export dirptr_h
.export file_size_l
.export file_size_h

.bss

disk_nfiles:	.res	1

.segment "ALBSS"

.align $100
floppy_status:	.res	$100
floppy_result:	.res	$100
bam:		.res	$100
file_size_l:	.res	$100
file_size_h:	.res	$100
file_type:	.res	$100
file_track:	.res	$100
file_sector:	.res	$100

directory:	.res	$2800

.data

mwcmd:		.byte	$20, $ff, $ff, "w-m"
mwcmd_len=	* - mwcmd

mecmd:		.byte	>DRV_RUN, <DRV_RUN, "e-m"
mecmd_len=	* - mecmd

dirptr_l:	.repeat $100,i
		.byte	<(directory+i*40)
		.endrep

dirptr_h:	.repeat $100,i
		.byte	>(directory+i*40)
		.endrep

filetypechar:	.byte	$13, $10, $15	; S, P, U

endtrack:	.byte	36, 41, 43

.code

floppy_detect:
		lda	#0
		sta	ZPS_0
		lda	#3
		sta	ZPS_1
fd_loop:	lda	#0
		sta	$90
		lda	ZPS_1
		ora	#8
		jsr	KRNL_LISTEN
		lda	#$6f
		jsr	KRNL_SECOND
		asl	$90
		bcs	fd_notfound
		lda	#'u'
		jsr	KRNL_CIOUT
		lda	#';'
		jsr	KRNL_CIOUT
		jsr	KRNL_UNLSN
		asl	$90
		bcs	fd_notfound
		lda	ZPS_1
		ora	#8
		jsr	KRNL_TALK
		lda	#$f
		jsr	KRNL_TKSA
		asl	$90
		bcs	fd_notfound
		lda	ZPS_1
		lsr	a
		ror	a
		ror	a
		tax
fd_statusloop:	jsr	KRNL_ACPTR
		bit	$90
		bmi	fd_statuserr
		bvs	fd_statusdone
		sta	floppy_status,x
		txa
		and	#$3f
		beq	fd_chkst0
		cmp	#1
		beq	fd_chkst1
fd_chkstok:	inx
		bne	fd_statusloop
fd_chkst0:	lda	#'7'
		bne	fd_chkst
fd_chkst1:	lda	#'3'
fd_chkst:	cmp	floppy_status,x
		beq	fd_chkstok
		jsr	KRNL_UNTLK
		sec
		bcs	fd_statuserr
fd_statusdone:	jsr	KRNL_UNTLK
		lda	#0
		sta	floppy_status,x
fd_statuserr:	asl	$90
fd_notfound:	rol	ZPS_0
		jsr	KRNL_UNLSN
		dec	ZPS_1
		bpl	fd_loop
		lda	ZPS_0
		eor	#$f
		rts

floppy_init:
		lda	#<((DRV_SIZE+$1f)>>5)
		sta	ZPS_0
		lda	#<DRV_RUN
		sta	mwcmd+2
		lda	#>DRV_RUN
		sta	mwcmd+1
		lda	#<(DRV_LOAD-$60)
		sta	fi_rdin+1
		lda	#>(DRV_LOAD-$60)
		sta	fi_rdin+2
fi_upload:	lda	#0
		sta	$90
		lda	$ba
		jsr	KRNL_LISTEN
		lda	#$6f
		jsr	KRNL_SECOND
		ldx	#mwcmd_len - 1
fi_mwhdr:	lda	mwcmd,x
		jsr	KRNL_CIOUT
		bit	$90
		bpl	fi_sendok
		jsr	KRNL_UNLSN
		sec
		rts
fi_sendok:	dex
		bpl	fi_mwhdr
		ldx	#$60
fi_rdin:	lda	$ffff,x
		jsr	KRNL_CIOUT
		inx
		bpl	fi_rdin
		jsr	KRNL_UNLSN
		dec	ZPS_0
		beq	fi_uploaded
		clc
		lda	#$20
		adc	fi_rdin+1
		sta	fi_rdin+1
		bcc	fi_readok
		inc	fi_rdin+2
		clc
fi_readok:	lda	#$20
		adc	mwcmd+2
		sta	mwcmd+2
		bcc	fi_upload
		inc	mwcmd+1
		bne	fi_upload
fi_uploaded:	lda	$ba
		jsr	KRNL_LISTEN
		lda	#$6f
		jsr	KRNL_SECOND
		ldx	#mecmd_len - 1
fi_sendme:	lda	mecmd,x
		jsr	KRNL_CIOUT
		dex
		bpl	fi_sendme
		jsr	KRNL_UNLSN
		clc
		rts

floppy_readdir:
		ldx	#0
		stx	disk_nfiles
		lda	#>directory
		sta	frd_clrdir+2
		ldy	#$28
		lda	#$20
frd_clrdir:	sta	$ff00,x
		inx
		bne	frd_clrdir
		inc	frd_clrdir+2
		dey
		bne	frd_clrdir
		jsr	getbyte
		cmp	#ST_OK
		beq	frd_bamloop
		sec
		rts
frd_bamloop:	jsr	getbyte
		sta	bam,y
		iny
		bne	frd_bamloop
		lda	#<directory
		sta	wd_store+1
		lda	#>directory
		sta	wd_store+2
		ldx	#0
		stx	ZPS_3
frd_dnameloop:	lda	bam+$90,x
		jsr	screencode
		cpx	#$12
		bcs	frd_dirrev
		cpx	#$10
		bcc	frd_dirrev
		inx
		bne	frd_dirchar
frd_dirrev:	ora	#$80
frd_dirchar:	jsr	writedir
		inx
		cpx	#$17
		bne	frd_dnameloop
frd_mainloop:	jsr	floppy_receive
		bcc	frd_parse
		clc
		lda	disk_nfiles
		rts
frd_parse:	lda	floppy_result
		cmp	#254
		bne	frd_done
		ldx	#0
		stx	ZPS_4
		beq	frd_firstentry
frd_done:	sec
		rts

frd_nextentry:	clc
		lda	ZPS_4
		adc	#$20
		bcs	frd_mainloop
		sta	ZPS_4
		tax
frd_firstentry:	ldy	floppy_result+1,x
		beq	frd_nextentry		; ignore DEL
		bpl	frd_nextentry		; ignore unclosed
		tya
		and	#$fc
		eor	#$80
		bne	frd_nextentry		; ignore REL + unknown types
		tya
		and	#3
		sta	frd_typeidx+1
		ldy	disk_nfiles
		sta	file_type,y
		lda	floppy_result+2,x
		sta	file_track,y
		lda	floppy_result+3,x
		sta	file_sector,y
		lda	floppy_result+$1d,x
		sta	file_size_l,y
		sta	ZPS_5
		lda	floppy_result+$1e,x
		sta	file_size_h,y
		sta	ZPS_6
		iny
		beq	frd_nextentry		; truncate after file #255
		sty	disk_nfiles
		lda	#0
		sta	ZPS_0
		sta	ZPS_1
		sta	ZPS_2
		lda	dirptr_l,y
		sta	wd_store+1
		lda	dirptr_h,y
		sta	wd_store+2
		ldx	#$10
frd_szloop:	ldy	#2
frd_addloop:	lda	ZPS_0,y
		cmp	#5
		bmi	frd_noadd
		adc	#2
		sta	ZPS_0,y
frd_noadd:	dey
		bpl	frd_addloop
		ldy	#2
		asl	ZPS_5
		rol	ZPS_6
frd_rolloop:	lda	ZPS_0,y
		rol	a
		cmp	#$10
		and	#$f
		sta	ZPS_0,y
frd_rolnext:	dey
		bpl	frd_rolloop
		dex
		bne	frd_szloop
		lda	ZPS_0
		ora	#$30
		jsr	startwritedir
		lda	ZPS_1
		ora	#$30
		jsr	writedir
		lda	ZPS_2
		ora	#$30
		jsr	writedir
		lda	#$20
		jsr	writedir

		ldx	ZPS_4
frd_nameloop:	lda	floppy_result+4,x
		jsr	screencode
		jsr	writedir
		inx
		txa
		and	#$f
		bne	frd_nameloop
		lda	#$20
		jsr	writedir
frd_typeidx:	ldx	#$ff
		lda	filetypechar-1,x
		jsr	writedir
		jmp	frd_nextentry

screencode:
		bmi	sc_shifted
		cmp	#$20
		bcc	sc_noprint
		cmp	#$60
		bcc	sc_lower
		and	#$df
		bne	sc_done
sc_noprint:	lda	#$20
		bne	sc_done
sc_lower:	and	#$3f
		bne	sc_done
sc_shifted:	cmp	#$ff
		bne	sc_nopi
		lda	#$5e
		bne	sc_done
sc_nopi:	and	#$7f
		cmp	#$20
		bcc	sc_noprint
		ora	#$40
sc_done:	rts

startwritedir:
		ldy	#0
		sty	ZPS_3

writedir:
		ldy	ZPS_3
wd_store:	sta	$ffff,y
		inc	ZPS_3
		rts

floppy_showdir:
		lda	#$0
		sta	fsd_store+1
		lda	#$a0
		sta	fsd_store+2
		lda	#25
		sta	ZPS_0
fsd_row:	lda	dirptr_l,x
		sta	fsd_load+1
		lda	dirptr_h,x
		sta	fsd_load+2
		ldy	#39
fsd_load:	lda	$ffff,y
fsd_store:	sta	$ffff,y
		dey
		bpl	fsd_load
		dec	ZPS_0
		bne	fsd_next
		rts
fsd_next:	inx
		clc
		lda	fsd_store+1
		adc	#40
		sta	fsd_store+1
		bcc	fsd_row
		inc	fsd_store+2
		bne	fsd_row

floppy_hashdisk:
		lda	#0
		jsr	sendbyte
		lda	endtrack,x
		bne	sendbyte

floppy_hashfile:
		lda	file_track,x
		jsr	sendbyte
		lda	file_sector,x

sendbyte:	sta	ZPS_0
		ldy	#8
sb_loop:	bit	CIA2_PRA
		bvc	sb_loop
		bpl	sb_loop
		lsr	ZPS_0
		lda	CIA2_PRA
		and	#$cf
		ora	#$10
		bcc	sb_zerobit
		eor	#$30
sb_zerobit:	sta	CIA2_PRA
		lda	#$c0
sb_waitack:	bit	CIA2_PRA
		bne	sb_waitack
		lda	CIA2_PRA
		and	#$cf
		sta	CIA2_PRA
		dey
		bne	sb_loop
		rts

floppy_receive:
		jsr	getbyte
		sec
		beq	fr_done
		sta	floppy_result
		tay
		ldx	#1
fr_loop:	jsr	getbyte
		sta	floppy_result,x
		inx
		dey
		bne	fr_loop
		clc
fr_done:	rts

getbyte:	sty	gb_ry+1
		ldy	#8
gb_loop:	lda	#$c0
		and	CIA2_PRA
		eor	#$c0
		beq	gb_loop
		asl	a
		lda	CIA2_PRA
		and	#$cf
		ora	#$20
		bcc	gb_skip
		eor	#$30
gb_skip:	sta	CIA2_PRA
		ror	ZPS_0
gb_wait:	lda	CIA2_PRA
		and	#$c0
		beq	gb_wait
		lda	CIA2_PRA
		and	#$cf
		sta	CIA2_PRA
		dey
		bne	gb_loop
gb_ry:		ldy	#$ff
		lda	ZPS_0
		rts
