.include "cia.inc"
.include "drv.inc"
.include "kernal.inc"
.include "statuscode.inc"
.include "timeout.inc"
.include "zpshared.inc"

.export floppy_detect
.export floppy_init
.export floppy_readdir
.export floppy_showdir
.export floppy_hashdisk
.export floppy_hashfile
.export floppy_receive

.export floppy_message
.export floppy_result
.export dirptr_l
.export dirptr_h
.export file_size_l
.export file_size_h

.bss

disk_nfiles:	.res	1
floppy_status:	.res	4

.segment "ALBSS"

.align $100
floppy_message:	.res	$100
floppy_result:	.res	$100
bam:		.res	$100
file_size_l:	.res	$100
file_size_h:	.res	$100
file_type:	.res	$100
file_track:	.res	$100
file_sector:	.res	$100

directory:	.res	$2800

.data

model_nodev:	.byte	"nodev", 0
model_unkwn:	.byte	"unkwn", 0
model_c1541:	.byte	"c1541", 0
model_c1570:	.byte	"c1570", 0
model_c1571:	.byte	"c1571", 0
model_c1581:	.byte	"c1581", 0

msg_notpresent:	.byte	"(device not present)", 0
msg_noresponse:	.byte	"(device did not respond)", 0
msg_noreset:	.byte	"(device ignored reset)", 0
msg_nofloppy:	.byte	"(not a floppy)", 0

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
		tax
		sta	floppy_message,x
		inx
		bne	*-4
		sta	ZPS_0
		ldx	#3
fd_listen:	stx	ZPS_1
		lda	#0			; clear serial bus status flags
		sta	$90
		sta	floppy_status,x
		txa
		ora	#8
		jsr	KRNL_LISTEN
		bit	$90			; check status directly
		bmi	fd_nolisten		; (READST just returns this)
		lda	#$6f
		jsr	KRNL_SECOND
		bit	$90
		bmi	fd_nolisten
		lda	#'u'			; send command for full ...
		jsr	KRNL_CIOUT
		bit	$90
		bmi	fd_nolisten
		lda	#'9'			; ... warmstart
		jsr	KRNL_CIOUT
		bit	$90
		bmi	fd_nolisten
		jsr	KRNL_UNLSN
		lda	#$40			; bit #6: device listened
		bit	$90
		bpl	fd_listened
		bmi	fd_unlsnerr
fd_nolisten:	jsr	KRNL_UNLSN
fd_unlsnerr:	lda	#0
fd_listened:	ldx	ZPS_1
		sta	floppy_status,x
		dex
		bpl	fd_listen

		ldx	#3
fd_talk:	stx	ZPS_1
		lda	floppy_status,x
		beq	fd_talknext		; didn't listen? -> skip
		lda	#<fd_timeout
		ldx	#>fd_timeout
		ldy	#50			; up to 500ms to receive status
		jsr	timeout_set
		lda	#0
		sta	$90
		lda	ZPS_1
		ora	#8
		jsr	KRNL_TALK
		bit	$90
		bmi	fd_notalk
		lda	#$f
		jsr	KRNL_TKSA
		bit	$90
		bmi	fd_notalk
		lda	ZPS_1			; turn index (0-3) into
		lsr	a			; offset ($00, $40, $80, $c0)
		ror	a
		ror	a
		tax
fd_messageloop:	jsr	KRNL_ACPTR		; read status message
		bit	$90
		bvs	fd_messagedone
		bmi	fd_messagedone		; terminate msg even on error
		sta	floppy_message,x
		inx
		txa
		and	#$3f
		bne	fd_messageloop
		dex
fd_messagedone:	lda	#0
		sta	floppy_message,x	; NUL-terminate message
		jsr	KRNL_UNTLK
		lda	#$80			; bit #7: device talked
		bit	$90
		bpl	fd_talked
		bmi	fd_untlkerr
fd_notalk:	jsr	KRNL_UNTLK
fd_untlkerr:	lda	#$0
fd_talked:	jsr	timeout_cancel
		ldx	ZPS_1
		ora	floppy_status,x
		sta	floppy_status,x
fd_talknext:	dex
		bpl	fd_talk
		bmi	fd_parse
fd_timeout:	lda	CIA2_PRA		; on timeout, try to recover:
		ora	#$38			; pull ATN/CLK/DATA low
		sta	CIA2_PRA
		ldy	#3			; wait a while
		ldx	#0
		inx
		bne	*-1
		dey
		bne	*-4
		and	#$c7			; release ATN/CLK/DATA
		sta	CIA2_PRA
		ldy	#3			; wait a while again
		inx
		bne	*-1
		dey
		bne	*-4
		stx	$90			; reset some KERNAL variables
		stx	$94
		stx	$98
		stx	$a3
		stx	$a4
		stx	$a5
		dex
		stx	$95
		ldx	ZPS_1			; try next device
		bpl	fd_talknext

fd_parse:	ldx	#3
fd_parseloop:	stx	ZPS_1
		txa
		lsr	a
		ror	a
		ror	a
		tay
		lda	floppy_status,x
		bpl	fd_checklsn
		sty	ZPS_2
		lda	floppy_message,y
		cmp	#'7'
		bne	fd_checkokst
		iny
		lda	floppy_message,y
		cmp	#'3'
		bne	fd_nofloppy
		iny
		lda	floppy_message,y
		cmp	#','
		bne	fd_nofloppy
		jmp	fd_identify
fd_checkokst:	cmp	#'0'
		bne	fd_nofloppy
		iny
		lda	floppy_message,y
		cmp	#'0'
		bne	fd_nofloppy
		iny
		lda	floppy_message,y
		cmp	#','
		bne	fd_nofloppy
		dey
		dey
		lda	#<model_unkwn
		sta	floppy_message,y
		iny
		lda	#>model_unkwn
		sta	floppy_message,y
		iny
		ldx	#0
fd_norstloop:	lda	msg_noreset,x
		sta	floppy_message,y
		beq	fd_notok
		iny
		inx
		bne	fd_norstloop
fd_nofloppy:	ldy	ZPS_2
		lda	#<model_unkwn
		sta	floppy_message,y
		iny
		lda	#>model_unkwn
		sta	floppy_message,y
		iny
		ldx	#0
fd_noflploop:	lda	msg_nofloppy,x
		sta	floppy_message,y
		beq	fd_notok
		iny
		inx
		bne	fd_noflploop
fd_checklsn:	beq	fd_nodev
		lda	#<model_unkwn
		sta	floppy_message,y
		iny
		lda	#>model_unkwn
		sta	floppy_message,y
		iny
		ldx	#0
fd_noresploop:	lda	msg_noresponse,x
		sta	floppy_message,y
		beq	fd_notok
		iny
		inx
		bne	fd_noresploop
fd_nodev:	lda	#<model_nodev
		sta	floppy_message,y
		iny
		lda	#>model_nodev
		sta	floppy_message,y
		iny
		ldx	#0
fd_nodevloop:	lda	msg_notpresent,x
		sta	floppy_message,y
		beq	fd_notok
		iny
		inx
		bne	fd_nodevloop
fd_notok:	clc
		bcc	fd_parsenext
fd_ok:		sec
fd_parsenext:	rol	ZPS_0
		ldx	ZPS_1
		dex
		bmi	fd_done
		jmp	fd_parseloop
fd_done:	lda	ZPS_0
		rts

fd_identify:	ldy	ZPS_2
		lda	#<(model_c1541+1)
		ldx	#>(model_c1541+1)
		jsr	fd_strstr
		bcc	fd_check1570
		ldy	ZPS_2
		lda	#<model_c1541
		sta	floppy_message,y
		iny
		lda	#>model_c1541
		sta	floppy_message,y
		jsr	fd_chopmsg
		beq	fd_ok
fd_check1570:	ldy	ZPS_2
		lda	#<(model_c1570+1)
		ldx	#>(model_c1570+1)
		jsr	fd_strstr
		bcc	fd_check1571
		ldy	ZPS_2
		lda	#<model_c1570
		sta	floppy_message,y
		iny
		lda	#>model_c1570
		sta	floppy_message,y
		jsr	fd_chopmsg
		beq	fd_ok
fd_check1571:	ldy	ZPS_2
		lda	#<(model_c1571+1)
		ldx	#>(model_c1571+1)
		jsr	fd_strstr
		bcc	fd_check1581
		ldy	ZPS_2
		lda	#<model_c1571
		sta	floppy_message,y
		iny
		lda	#>model_c1571
		sta	floppy_message,y
		jsr	fd_chopmsg
		beq	fd_ok
fd_check1581:	ldy	ZPS_2
		lda	#<(model_c1581+1)
		ldx	#>(model_c1581+1)
		jsr	fd_strstr
		ldy	ZPS_2
		bcc	fd_unkwnflp
		lda	#<model_c1581
		sta	floppy_message,y
		iny
		lda	#>model_c1581
		sta	floppy_message,y
		bcs	fd_checkdone
fd_unkwnflp:	lda	#<model_unkwn
		sta	floppy_message,y
		iny
		lda	#>model_unkwn
		sta	floppy_message,y
fd_checkdone:	jsr	fd_chopmsg
		jmp	fd_notok

fd_strstr:	sta	fd_ssndlrd1+1
		sta	fd_ssndlrd2+1
		stx	fd_ssndlrd1+2
		stx	fd_ssndlrd2+2
fd_ssloop:	lda	floppy_message,y
		beq	fd_ssnotfound
fd_ssndlrd1:	cmp	$ffff
		beq	fd_ssndlscan
		iny
		bne	fd_ssloop
fd_ssnotfound:	clc
		rts
fd_ssndlscan:	iny
		sty	fd_ssrsty+1
		ldx	#1
fd_ssndlrd2:	lda	$ffff,x
		beq	fd_ssfound
		cmp	floppy_message,y
		bne	fd_ssrsty
		iny
		inx
		bne	fd_ssndlrd2
fd_ssrsty:	ldy	#$ff
		bne	fd_ssloop
fd_ssfound:	sec
		rts

fd_chopmsg:	iny
		lda	#'('
		sta	floppy_message,y
fd_choploop:	iny
		lda	floppy_message,y
		cmp	#','
		bne	fd_choploop
		lda	#')'
		sta	floppy_message,y
		iny
		lda	#0
		sta	floppy_message,y
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
