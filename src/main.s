.segment "BHDR"

		.word	$0801
		.word	hdrend
		.word	2026
		.byte	$9e, "2061", 0
hdrend:		.word	0

.segment "ENTRY"

entry:		rts

