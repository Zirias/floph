.include "cia.inc"
.include "drv.inc"
.include "kernal.inc"
.include "zpshared.inc"

.export floppy_init
.export floppy_readdir
.export floppy_showdir
.export floppy_hashfile
.export floppy_receive

.export floppy_result

.bss

disk_nfiles:	.res	1
floppy_result:	.res	$100

.segment "ALBSS"

.align $100
file_size_l:	.res	$100
file_size_h:	.res	$100
file_type:	.res	$100
file_track:	.res	$100
file_sector:	.res	$100
file_havehash:	.res	$100
file_hash:	.res	$800

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

.code

floppy_init:
		sta	$ba
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
fi_upload:	lda	$ba
		jsr	KRNL_LISTEN
		jsr	KRNL_READST
		bpl	fi_proceed
		sec
		rts
fi_proceed:	lda	#$6f
		jsr	KRNL_SECOND
		ldx	#mwcmd_len - 1
fi_mwhdr:	lda	mwcmd,x
		jsr	KRNL_CIOUT
		dex
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
		jsr	floppy_receive
		bcc	frd_diskid
		rts
frd_diskid:	lda	floppy_result
		cmp	#$17
		beq	frd_diskok
		sec
		rts
frd_diskok:	lda	#<directory
		sta	wd_store+1
		lda	#>directory
		sta	wd_store+2
		ldx	#0
		stx	ZPS_3
frd_dnameloop:	lda	floppy_result+1,x
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
		rts
frd_parse:	lda	floppy_result
		cmp	#21
		beq	frd_ok0
		sec
		rts
frd_ok0:	ldx	floppy_result+1
		beq	frd_mainloop		; ignore DEL
		bpl	frd_mainloop		; ignore unclosed
		txa
		and	#$fc
		eor	#$80
		bne	frd_mainloop		; ignore REL + unknown types
		txa
		and	#3			; mask type bits
		ldx	disk_nfiles
		sta	file_type,x
		lda	floppy_result+2
		sta	file_track,x
		lda	floppy_result+3
		sta	file_sector,x
		lda	floppy_result+20
		sta	file_size_l,x
		lda	floppy_result+21
		sta	file_size_h,x
		lda	#0
		sta	file_havehash,x
		sta	ZPS_0
		sta	ZPS_1
		sta	ZPS_2
		inx
		beq	frd_mainloop		; truncate after file #255
		stx	disk_nfiles
		lda	dirptr_l,x
		sta	wd_store+1
		lda	dirptr_h,x
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
		asl	floppy_result+20
		rol	floppy_result+21
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
		ldx	#0
frd_nameloop:	lda	floppy_result+4,x
		jsr	screencode
		jsr	writedir
		inx
		cpx	#$10
		bne	frd_nameloop
		lda	#$20
		jsr	writedir
		lda	floppy_result+1
		and	#$3
		tax
		lda	filetypechar-1,x
		jsr	writedir
		jmp	frd_mainloop

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

floppy_hashfile:
		stx	fhf_read+2
		tax
fhf_read:	lda	$ff00,x
		beq	sendbyte
		jsr	sendbyte
		inx
		bne	fhf_read
		inc	fhf_read+2
		bne	fhf_read

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
