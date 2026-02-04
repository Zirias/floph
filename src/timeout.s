.include "cia.inc"

.export timeout_set
.export timeout_cancel

.bss

nmivec:		.res 2

.code

; timeout_set: Schedule a timeout in cs
;
; Schedule a NMI using CIA#2 to fire in (roughly) a given number of
; centiseconds. When the NMI fires, unroll the stack and jump to a given
; address. The restored stack-pointer will be the one of the caller, as
; if timeout_set returned a second time.
;
;	A/X	Address to jump to on timeout (lo/hi)
;	Y	Timeout in cs
;
; Clobbers:	A, X, Y, SR (NZ)
;
; Constraints:	- Needs the KERNAL banked in (uses its soft vector at $318).
;		  This vector is restored after a timeout occured or was
;		  canceled.
;		- NOT reentrant, scheduling a second timeout will likely crash.
;		- On timeout, any state (all registers and status) must be
;		  considered garbage, because it might interrupt any code at
;		  any point.
;		- CIA#2 timer and interrupt configuration is not preserved,
;		  after cancelling a timeout, the timers keep running (until
;		  underflow) and CIA#2 interrupts are disabled.
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

; timeout_cancel: Cancel a previously scheduled timeout
;
; Use this to cancel the scheduled timeout. If the timeout already occured,
; it was automatically called.
;
; Clobbers:	Y, SR (NZ)
timeout_cancel:
		ldy	#$7f
		sty	CIA2_ICR
		ldy	nmivec
		sty	$318
		ldy	nmivec+1
		sty	$319
		rts

