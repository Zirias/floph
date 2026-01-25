.include "cia.inc"
.include "floppy.inc"
.include "vic.inc"
.include "zpshared.inc"

.export tui_run

KB_NONE=	0
KB_RIGHT=	1
KB_DOWN=	2
KB_LEFT=	3
KB_UP=		4
KB_ENTER=	5
KB_STOP=	6

.bss

cmd:		.res	1
lastkey:	.res	1
keyrepwait1:	.res	1
keyrepwait2:	.res	1
scrollpos:	.res	1
selrow:		.res	1
dirpos:		.res	1
nfiles:		.res	1
save_bgcol:	.res	1
save_bordercol:	.res	1

.segment "ALBSS"

.align $100
save_colors:	.res	$400

.code

tui_run:
		sta	nfiles
		lda	#$7f
		sta	CIA1_ICR
		ldx	#0
		stx	scrollpos
		stx	cmd
		jsr	floppy_showdir
		lda	BORDER_COLOR
		sta	save_bordercol
		lda	BG_COLOR_0
		sta	save_bgcol
		lda	#$d8
		sta	ti_savecolrd+2
		sta	ti_initcolwr+2
		lda	#>save_colors
		sta	ti_savecolwr+2
		ldy	#4
		ldx	#0
ti_savecolrd:	lda	$ff00,x
ti_savecolwr:	sta	$ff00,x
		inx
		bne	ti_savecolrd
		inc	ti_savecolrd+2
		inc	ti_savecolwr+2
		dey
		bne	ti_savecolrd
ti_wait1:	lda	VIC_RASTER
		bne	ti_wait1
		bit	VIC_CTL1
		bmi	ti_wait1
		ldx	#8
		stx	BORDER_COLOR
		inx
		stx	BG_COLOR_0
		lda	#$85
		sta	VIC_MEMCTL
		lda	CIA2_PRA
		and	#$fd
		sta	CIA2_PRA
		ldx	#0
		ldy	#4
		lda	#7
ti_initcolwr:	sta	$ff00,x
		inx
		bne	ti_initcolwr
		inc	ti_initcolwr+2
		dey
		bne	ti_initcolwr
		lda	#<isr0
		sta	$fffe
		lda	#>isr0
		sta	$ffff
		lda	#<i0_rti
		sta	$fffa
		lda	#>i0_rti
		sta	$fffb
		lda	#$ff
		sta	VIC_RASTER
		lda	#$1b
		sta	VIC_CTL1
		lda	#0
		sta	CIA2_CRA
		sta	CIA2_TA_LO
		sta	CIA2_TA_HI
		lda	#$35
		sta	$1
		lda	#$81
		sta	CIA2_ICR
		lda	#$1
		sta	CIA2_CRA
		sta	VIC_IRM
		asl	VIC_IRR
		lda	#1
		sta	selrow
		sta	dirpos

cmdloop:	lda	#0
		sta	cmd
cmdwait:	lda	cmd
		beq	cmdwait
		bmi	scrollup
		lsr	a
		bcs	scrolldown
		lsr	a
		bcs	hashfile
		jmp	tui_done
hashfile:	ldx	dirpos
		beq	cmdloop
		lda	#0
		sta	lastkey
		dex
		jsr	floppy_hashfile
		jmp	showhash

scrolldown:	ldx	scrollpos
		inx
		stx	scrollpos
		jsr	floppy_showdir
		jmp	cmdloop
scrollup:	ldx	scrollpos
		dex
		stx	scrollpos
		jsr	floppy_showdir
		jmp	cmdloop

showhash:	ldx	dirpos
		lda	dirptr_l,x
		sta	houthd+1
		sta	houtld+1
		lda	dirptr_h,x
		sta	houthd+2
		sta	houtld+2
		lda	#0
		sta	ZPS_5
		lda	selrow
		asl	a
		asl	a
		asl	a
		sta	ZPS_4
		asl	a
		rol	ZPS_5
		asl	a
		rol	ZPS_5
		adc	ZPS_4
		bcc	*+4
		inc	ZPS_5
		sta	houths+1
		sta	houtls+1
		lda	ZPS_5
		ora	#$a0
		sta	houths+2
		sta	houtls+2

		jsr	floppy_receive
		lda	floppy_result
		cmp	#8
		beq	hashout
hashout:	ldy	#23
		ldx	#8
houtloop:	lda	floppy_result,x
		lsr
		lsr
		lsr
		lsr
		ora	#$30
		cmp	#$3a
		bcc	houths
		sbc	#$39
houths:		sta	$ffff,y
houthd:		sta	$ffff,y
		iny
		lda	floppy_result,x
		and	#$f
		ora	#$30
		cmp	#$3a
		bcc	houtls
		sbc	#$39
houtls:		sta	$ffff,y
houtld:		sta	$ffff,y
		iny
		dex
		bne	houtloop
		jmp	cmdloop

tui_done:
		lda	#0
		sta	VIC_IRM
		lda	#$d8
		sta	td_restcolwr+2
		lda	#>save_colors
		sta	td_restcolrd+2
td_wait1:	lda	VIC_RASTER
		bne	td_wait1
		bit	VIC_CTL1
		bmi	td_wait1
		lda	save_bordercol
		sta	BORDER_COLOR
		lda	save_bgcol
		sta	BG_COLOR_0
		lda	#$15
		sta	VIC_MEMCTL
		lda	CIA2_PRA
		ora	#3
		sta	CIA2_PRA
		ldy	#4
		ldx	#0
td_restcolrd:	lda	$ff00,x
td_restcolwr:	sta	$ff00,x
		inx
		bne	td_restcolrd
		inc	td_restcolrd+2
		inc	td_restcolwr+2
		dey
		bne	td_restcolrd
		lda	#$37
		sta	$1
		lda	#$81
		sta	CIA1_ICR
		lda	CIA2_ICR
		lda	#$ff
		sta	CIA1_DDRA
		rts

isr0:
		sta	i0_ra+1
		stx	i0_rx+1
		lda	selrow
		asl
		asl
		asl
		adc	#$32
		sta	VIC_RASTER
		lda	#<isr1
		sta	$fffe
		lda	#>isr1
		sta	$ffff
		asl	VIC_IRR
		lda	#1
		sta	i0_kcbase+1
		lda	cmd
		beq	i0_dokb
		jmp	i0_skipkb
i0_dokb:	lda	CIA1_PRA
		and	#$1f
		eor	#$1f
		beq	i0_nojs
		jmp	i0_skipkb
i0_nojs:	lda	#$ff
		sta	CIA1_DDRA
		lda	#$7f
		sta	CIA1_PRA
		lda	#$4
		bit	CIA1_PRB
		beq	i0_kbinval	; control
		bpl	i0_stopkey
		lda	#$bf
		sta	CIA1_PRA
		lda	CIA1_PRB
		and	#$10		; right shift
		bne	i0_norshift
		lda	#3
		sta	i0_kcbase+1
i0_norshift:	lda	#$fd
		sta	CIA1_PRA
		lda	CIA1_PRB
		and	#$80		; left shift
		bne	i0_nolshift
		lda	#3
		sta	i0_kcbase+1
i0_nolshift:	lda	#$fe
		sta	CIA1_PRA
		lda	CIA1_PRB
i0_kcbase:	ldx	#1
		lsr	a
		lsr	a
		bcs	i0_noenter
		ldx	#KB_ENTER
		bne	i0_kbval
i0_noenter:	lsr	a
		bcc	i0_kbval
		inx
		and	#$10
		bne	i0_kbinval
		beq	i0_kbval
i0_stopkey:	ldx	#6
i0_kbval:	txa
		cmp	lastkey
		sta	lastkey
		beq	i0_kbcheckrep
		lda	#20
		sta	keyrepwait1
i0_handlekey:	dex
		beq	i0_kbdone
		dex
		beq	i0_down
		dex
		beq	i0_kbdone
		dex
		beq	i0_up
		lda	#$2
		dex
		beq	i0_storecmd
		asl	a
i0_storecmd:	sta	cmd
		bne	i0_kbdone
i0_kbinval:	lda	#$0
		sta	lastkey
i0_kbdone:	lda	#$0
		sta	CIA1_DDRA
i0_skipkb:
i0_rx:		ldx	#$ff
i0_ra:		lda	#$ff
i0_rti:		rti
i0_kbcheckrep:	lda	keyrepwait1
		beq	i0_dorep
		dec	keyrepwait1
		bne	i0_kbdone
		lda	#$3
		sta	keyrepwait2
i0_dorep:	dec	keyrepwait2
		bne	i0_kbdone
		lda	#$3
		sta	keyrepwait2
		bne	i0_handlekey
i0_up:		ldx	dirpos
		beq	i0_kbdone
		dex
		stx	dirpos
		ldx	selrow
		cpx	#4
		bne	i0_uns
		lda	scrollpos
		beq	i0_uns
		lda	#$80
		sta	cmd
		bmi	i0_kbdone
i0_uns:		dex
		stx	selrow
		bpl	i0_kbdone
i0_down:	ldx	dirpos
		cpx	nfiles
		beq	i0_kbdone
		inx
		stx	dirpos
		ldx	selrow
		cpx	#20
		bne	i0_dns
		lda	scrollpos
		clc
		adc	#24
		cmp	nfiles
		bcs	i0_dns
		lda	#$1
		sta	cmd
		bne	i0_kbdone
i0_dns:		inx
		stx	selrow
		bpl	i0_kbdone

isr1:
		sta	i1_ra+1
		lda	VIC_RASTER
		clc
		adc	#8
		sta	VIC_RASTER
		lda	#<isr2
		sta	$fffe
		lda	#>isr2
		sta	$ffff
		asl	VIC_IRR
		asl	VIC_IRR
		asl	VIC_IRR
		lda	#6
		sta	BG_COLOR_0
i1_ra:		lda	#$ff
		rti

isr2:
		sta	i2_ra+1
		lda	#$ff
		sta	VIC_RASTER
		lda	#<isr0
		sta	$fffe
		lda	#>isr0
		sta	$ffff
		asl	VIC_IRR
		asl	VIC_IRR
		asl	VIC_IRR
		asl	VIC_IRR
		lda	#9
		sta	BG_COLOR_0
i2_ra:		lda	#$ff
		rti

