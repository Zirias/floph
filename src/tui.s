.include "cia.inc"
.include "floppy.inc"
.include "vic.inc"

.export tui_init
.export tui_done

.bss

scrollpos:	.res	1
selrow:		.res	1
save_bgcol:	.res	1
save_bordercol:	.res	1

.segment "ALBSS"

.align $100
save_colors:	.res	$400

.code

tui_init:
		lda	#$7f
		sta	CIA1_ICR
		ldx	#0
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
		lda	#$ff
		sta	VIC_RASTER
		lda	#$1b
		sta	VIC_CTL1
		lda	#$35
		sta	$1
		lda	#$1
		sta	VIC_IRM
		asl	VIC_IRR
		lda	#1
		sta	selrow

		jmp	*

isr0:
		sta	i0_ra+1
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
i0_ra:		lda	#$ff
		rti

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

tui_done:
		rts
