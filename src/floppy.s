.include "cia.inc"
.include "drv.inc"
.include "kernal.inc"
.include "zpshared.inc"

.export floppy_init
.export floppy_hashfile
.export floppy_receive

.export floppy_result

.data

mwcmd:		.byte	$20, $ff, $ff, "w-m"
mwcmd_len=	* - mwcmd

mecmd:		.byte	>DRV_RUN, <DRV_RUN, "e-m"
mecmd_len=	* - mecmd

.bss

floppy_result:	.res	$100

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
		lda	#$6f
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
		jmp	KRNL_UNLSN

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
		ror	ZPS_0
		lda	CIA2_PRA
		ora	#$30
		sta	CIA2_PRA
gb_wait:	lda	CIA2_PRA
		and	#$c0
		bne	gb_wait
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
