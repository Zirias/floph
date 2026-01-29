.export fnv1a_init
.export fnv1a_hashbuf
.export fnv1a_hashbyte

.exportzp fnv1a_hash

.segment "DRV"
		; Initial hash value: 0xcbf29ce484222325
fnv1a_initval:	.byte	$25, $23, $22, $84, $e4, $9c, $f2, $cb
FNV1A_SIZE=	* - fnv1a_initval

.segment "DRVZP0": zeropage

fnv1a_hash:	.res	FNV1A_SIZE

.segment "DRVZP1": zeropage

fnv1a_tmp:	.res	FNV1A_SIZE

.segment "DRV"

fnv1a_init:
		ldx	#FNV1A_SIZE-1
fi_loop:	lda	fnv1a_initval,x
		sta	fnv1a_hash,x
		dex
		bpl	fi_loop
		rts

; fnv1a_hashbuf: Add buffer to current fnv1a hashing process
;
;	A (in)			high-byte of buffer address
;	Y (in)			bytes to hash
;	fnv1a_hash (ZP,in/out)	64bit hash in little endian
;
;	clobbers:		A, X, Y, SR (all flags)
;
fnv1a_hashbuf:
		sta	fnv1a_mainloop+2
		stx	fnv1a_mainloop+1
		ldx	#0
fnv1a_hashbyte=	*-1
		beq	fnv1a_mainloop
		lda	#0
		sta	fnv1a_hashbyte
		txa
		ldy	#1
		bne	fnv1a_hashone
fnv1a_mainloop:	lda	$ffff
fnv1a_hashone:	eor	fnv1a_hash
		sta	fnv1a_hash
		sta	fnv1a_tmp

		.repeat	5, B
		lda	fnv1a_hash+1+B
		sta	fnv1a_tmp+1+B
		.endrep
		clc
		adc	fnv1a_tmp
		sta	fnv1a_hash+5
		.repeat 2, B
		lda	fnv1a_hash+6+B
		sta	fnv1a_tmp+6+B
		adc	fnv1a_tmp+1+B
		sta	fnv1a_hash+6+B
		.endrep

		lda	#$d9

fnv1a_mult:	asl	fnv1a_tmp
		.repeat FNV1A_SIZE-1, B
		rol	fnv1a_tmp+1+B
		.endrep
		lsr	a
		bcc	fnv1a_mult
		tax

		clc
		.repeat FNV1A_SIZE, B
		lda	fnv1a_tmp+B
		adc	fnv1a_hash+B
		sta	fnv1a_hash+B
		.endrep
		txa
		bne	fnv1a_mult

		dey
		bne	fnv1a_step
		rts

fnv1a_step:	inc	fnv1a_mainloop+1
		bne	fnv1a_next
		inc	fnv1a_mainloop+2
fnv1a_next:	jmp	fnv1a_mainloop

