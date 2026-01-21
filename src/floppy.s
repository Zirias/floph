.include "drv.inc"
.include "kernal.inc"
.include "zpshared.inc"

.export floppy_init

.data

mwcmd:		.byte	$20, $ff, $ff, "w-m"
mwcmd_len=	* - mwcmd

mecmd:		.byte	>DRV_RUN, <DRV_RUN, "e-m"
mecmd_len=	* - mecmd

.code

floppy_init:	sta	$ba
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

