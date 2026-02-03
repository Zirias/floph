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
drv8msg:	.byte	"8  ", 0
drv9msg:	.byte	"9  ", 0
drv10msg:	.byte	"10 ", 0
drv11msg:	.byte	"11 ", 0
detecterrtxt:	.byte	"no drives found!", $d, 0
menuhead:	.byte	"select drive to start floph:", $d, $d, 0
drv8entry:	.byte	" drive #8  ", $d, 0
drv9entry:	.byte	" drive #9  ", $d, 0
drv10entry:	.byte	" drive #10 ", $d, 0
drv11entry:	.byte	" drive #11 ", $d, 0
cancelentry:	.byte	"  cancel   ", $d, 0
connecttxt:	.byte	"connecting to drive ... ", $d, 0
uploaderrtxt:	.byte	"error uploading drive code!", $d, 0
direrrortxt:	.byte	"error loading directory!", $d, 0

.bss

menulen:	.res	1
menupos:	.res	1
menuscrl:	.res	5
menuscrh:	.res	5
menudrv:	.res	5

.macro		drvres	msg, num
		lda	#<msg
		ldx	#>msg
		jsr	puts
		lda	floppy_message+64*num
		ldx	floppy_message+64*num+1
		jsr	puts
		lda	#' '
		jsr	KRNL_CHROUT
		lda	#<(floppy_message+64*num+2)
		ldx	#>(floppy_message+64*num+2)
		jsr	puts
		lda	#$d
		jsr	KRNL_CHROUT
.endmacro

.segment "ENTRY"

entry:		lda	#<detectingtxt
		ldx	#>detectingtxt
		jsr	puts
		jsr	floppy_detect
		sta	ZPS_0
		drvres	drv8msg, 0
		drvres	drv9msg, 1
		drvres	drv10msg, 2
		drvres	drv11msg, 3
		lda	#$d
		jsr	KRNL_CHROUT

		lda	ZPS_0
		bne	drivemenu
		lda	#<detecterrtxt
		ldx	#>detecterrtxt
		jmp	puts

drivemenu:	sta	ZPS_1
		lda	#$ff
		sta	ZPS_2
		lda	#1
		sta	menulen
		lda	#<menuhead
		ldx	#>menuhead
		jsr	puts
		lda	ZPS_0
		sta	ZPS_1
		ldx	#0
		stx	ZPS_2
		lsr	ZPS_1
		bcc	dm_skip8
		inc	menulen
		lda	#<drv8entry
		ldx	#>drv8entry
		jsr	puts
		lda	#8
		ldx	ZPS_2
		sta	menudrv,x
		inx
		stx	ZPS_2
dm_skip8:	lsr	ZPS_1
		bcc	dm_skip9
		inc	menulen
		lda	#<drv9entry
		ldx	#>drv9entry
		jsr	puts
		lda	#9
		ldx	ZPS_2
		sta	menudrv,x
		inx
		stx	ZPS_2
dm_skip9:	lsr	ZPS_1
		bcc	dm_skip10
		inc	menulen
		lda	#<drv10entry
		ldx	#>drv10entry
		jsr	puts
		lda	#10
		ldx	ZPS_2
		sta	menudrv,x
		inx
		stx	ZPS_2
dm_skip10:	lsr	ZPS_1
		bcc	dm_start
		inc	menulen
		lda	#<drv11entry
		ldx	#>drv11entry
		jsr	puts
		lda	#11
		ldx	ZPS_2
		sta	menudrv,x
		inx
		stx	ZPS_2
dm_start:	lda	#<cancelentry
		ldx	#>cancelentry
		jsr	puts
		lda	#0
		ldx	ZPS_2
		sta	menudrv,x
		ldy	$d6
dm_fillptrs:	dey
		lda	$d9,y
		and	#$7f
		sta	menuscrh,x
		lda	$ecf0,y
		sta	menuscrl,x
		dex
		bpl	dm_fillptrs
		lda	#0
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
		bne	connect
		rts

connect:	sta	$ba
		lda	#<connecttxt
		ldx	#>connecttxt
		jsr	puts
		jsr	floppy_init
		bcc	displaydir
		lda	#<uploaderrtxt
		ldx	#>uploaderrtxt
		jmp	puts
displaydir:	jsr	floppy_readdir
		bcs	direrror
		jmp	tui_run
direrror:	lda	#<direrrortxt
		ldx	#>direrrortxt

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
