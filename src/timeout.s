.include "cia.inc"

.export timeout_set
.export timeout_cancel

.bss

nmivec:		.res 2

.code

timeout_set:
		sta	toisr_jmp+1
		stx	toisr_jmp+2
		lda	#$7f
		sta	CIA2_ICR
		lda	CIA2_ICR
		lda	#0
		sta	CIA2_CRA
		sta	CIA2_CRB
		sty	CIA2_TB_LO
		sta	CIA2_TB_HI
		tsx
		stx	toisr_timeout+1
		lda	$318
		sta	nmivec
		lda	$319
		sta	nmivec+1
		lda	#<toisr
		sta	$318
		lda	#>toisr
		sta	$319
		lda	#$7c
		ldx	#$26
		ldy	$2a6
		bne	tos_seta
		lda	#$f3
		inx
tos_seta:	sta	CIA2_TA_LO
		stx	CIA2_TA_HI
		lda	#$82
		sta	CIA2_ICR
		lda	#$11
		sta	CIA2_CRA
		lda	#$51
		sta	CIA2_CRB
		rts

toisr:
		lda	CIA2_ICR
		and	#2
		bne	toisr_timeout
		jmp	(nmivec)
toisr_timeout:	ldx	#$ff
		txs
		pla
		pla
		cli
		jsr	timeout_cancel
toisr_jmp:	jmp	$ffff

timeout_cancel:
		ldy	#$7f
		sty	CIA2_ICR
		ldy	CIA2_ICR
		ldy	nmivec
		sty	$318
		ldy	nmivec+1
		sty	$319
		rts

