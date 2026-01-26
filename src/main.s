.include "floppy.inc"
.include "kernal.inc"
.include "tui.inc"
.include "zpshared.inc"

.segment "BHDR"

		.word	$0801
		.word	hdrend
		.word	2026
		.byte	$9e, "2061", 0
hdrend:		.word	0

.data

detectingtxt:	.byte	$d, "floph, the floppy hasher", $d
		.byte	"2026 by zirias", $d, $d
		.byte	"detecting disk drives ... ", $d, 0
detecterrtxt:	.byte	"no drives found!", $d, 0
foundtxt:	.byte	"found drive(s): ", 0
drvnotxt:	.byte	"11", 0, 0
		.byte	"10", 0, 0
		.byte	"9", 0, 0, 0
		.byte	"8", 0
menuhead:	.byte	"select drive:", $d, 0
drv8entry:	.byte	" drive #8  ", $d, 0
drv9entry:	.byte	" drive #9  ", $d, 0
drv10entry:	.byte	" drive #10 ", $d, 0
drv11entry:	.byte	" drive #11 ", $d, 0
connecttxt:	.byte	"connecting to drive ... ", $d, 0
uploaderrtxt:	.byte	"error uploading drive code!", $d, 0

.bss

menulen:	.res	1
menupos:	.res	1
menuscrl:	.res	4
menuscrh:	.res	4
menudrv:	.res	4

.segment "ENTRY"

entry:		lda	#<detectingtxt
		ldx	#>detectingtxt
		jsr	puts
		jsr	floppy_detect
		bne	drivesfound
		lda	#<detecterrtxt
		ldx	#>detecterrtxt
		jmp	puts
drivesfound:	sta	ZPS_0
		sta	ZPS_1
		lda	#$ff
		sta	ZPS_2

		lda	#<foundtxt
		ldx	#>foundtxt
		jsr	puts

		lda	#<(drvnotxt+16)
		sta	drvnooutl+1
		lda	#>(drvnotxt+16)
		sta	drvnoouth+1
		ldy	#4
drvfoundloop:	sec
		lda	drvnooutl+1
		sbc	#4
		sta	drvnooutl+1
		bcs	drvfoundnext
		dec	drvnoouth+1
drvfoundnext:	dey
		bmi	drvfounddone
		lsr	ZPS_1
		bcc	drvfoundloop
		inc	ZPS_2
		beq	drvnoout
		lda	#','
		jsr	KRNL_CHROUT
		lda	#$20
		jsr	KRNL_CHROUT
drvnoout:	sty	ZPS_3
drvnooutl:	lda	#$ff
drvnoouth:	ldx	#$ff
		jsr	puts
		ldy	ZPS_3
		bpl	drvfoundloop
drvfounddone:	lda	#$d
		jsr	KRNL_CHROUT
		lda	#$d
		jsr	KRNL_CHROUT

		lda	ZPS_2
		bne	drivemenu

		lda	ZPS_0
		ldx	#8
findfirst:	lsr	a
		bcs	usefirst
		inx
		bne	findfirst
usefirst:	stx	$ba
		jmp	connect

drivemenu:	tax
		inx
		stx	menulen
		lda	#<menuhead
		ldx	#>menuhead
		jsr	puts
		lda	ZPS_0
		sta	ZPS_1
		lda	#0
		sta	ZPS_2
		lsr	ZPS_1
		bcc	dm_skip8
		lda	#8
		ldx	ZPS_2
		sta	menudrv,x
		ldy	$d6
		lda	$d9,y
		and	#$7f
		sta	menuscrh,x
		lda	$ecf0,y
		sta	menuscrl,x
		lda	#<drv8entry
		ldx	#>drv8entry
		jsr	puts
		inc	ZPS_2
dm_skip8:	lsr	ZPS_1
		bcc	dm_skip9
		lda	#9
		ldx	ZPS_2
		sta	menudrv,x
		ldy	$d6
		lda	$d9,y
		and	#$7f
		sta	menuscrh,x
		lda	$ecf0,y
		sta	menuscrl,x
		lda	#<drv9entry
		ldx	#>drv9entry
		jsr	puts
		inc	ZPS_2
dm_skip9:	lsr	ZPS_1
		bcc	dm_skip10
		lda	#10
		ldx	ZPS_2
		sta	menudrv,x
		ldy	$d6
		lda	$d9,y
		and	#$7f
		sta	menuscrh,x
		lda	$ecf0,y
		sta	menuscrl,x
		lda	#<drv10entry
		ldx	#>drv10entry
		jsr	puts
		inc	ZPS_2
dm_skip10:	lsr	ZPS_1
		bcc	dm_start
		lda	#11
		ldx	ZPS_2
		sta	menudrv,x
		ldy	$d6
		lda	$d9,y
		and	#$7f
		sta	menuscrh,x
		lda	$ecf0,y
		sta	menuscrl,x
		lda	#<drv11entry
		ldx	#>drv11entry
		jsr	puts
		inc	ZPS_2
dm_start:	lda	#0
		sta	menupos
dm_invloop:	jsr	menu_inv
dm_loop:	jsr	KRNL_GETIN
		beq	dm_loop
		cmp	#$d
		beq	dm_done
		cmp	#$11
		beq	dm_down
		cmp	#$91
		bne	dm_loop
		ldx	menupos
		beq	dm_loop
		jsr	menu_inv
		dec	menupos
		bpl	dm_invloop
dm_down:	ldx	menupos
		inx
		cpx	menulen
		beq	dm_loop
		jsr	menu_inv
		inc	menupos
		bpl	dm_invloop
dm_done:	lda	#$d
		jsr	KRNL_CHROUT
		ldx	menupos
		lda	menudrv,x
		sta	$ba

connect:	lda	#<connecttxt
		ldx	#>connecttxt
		jsr	puts
		jsr	floppy_init
		bcc	displaydir
		lda	#<uploaderrtxt
		ldx	#>uploaderrtxt
		jmp	puts
displaydir:	jsr	floppy_readdir
		jmp	tui_run

puts:		sta	putsrd+1
		stx	putsrd+2
		ldy	#0
putsrd:		lda	$ffff,y
		beq	putsdone
		jsr	KRNL_CHROUT
		iny
		bne	putsrd
putsdone:	rts

menu_inv:	ldy	#10
		ldx	menupos
		lda	menuscrl,x
		sta	mi_rd+1
		sta	mi_wr+1
		lda	menuscrh,x
		sta	mi_rd+2
		sta	mi_wr+2
mi_rd:		lda	$ffff,y
		eor	#$80
mi_wr:		sta	$ffff,y
		dey
		bpl	mi_rd
		rts
