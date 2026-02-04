CA65?=		ca65
LD65?=		ld65
CA65FLAGS+=	-t c64 -g
LD65FLAGS+=	-Ln $(TARGET).lbl -m $(TARGET).map -C src/$(TARGET).cfg

CC?=		cc
CFLAGS?=	-Wall -Wextra -pedantic -O3
STRIP?=		strip

C1541?=		c1541
DISKNAME=	$(TARGET)-test
ERRDISKNAME=	$(TARGET)-errtest

ifeq ($(OS),Windows_NT)
BINEXT:=	.exe
else
BINEXT:=	#
endif

TARGET=		floph

MODULES=	main zpshared floppy timeout tui drv fnv1a

OBJS=		$(addprefix obj/,$(addsuffix .o,$(MODULES)))

all:		$(TARGET).prg pfloph$(BINEXT)
disk:		$(DISKNAME).d64
errdisk:	$(ERRDISKNAME).d64

$(DISKNAME).d64:	$(TARGET).prg LICENSE.txt Makefile README.md pfloph.c
	$(C1541) -format $(TARGET),fh d64 $@ 8 \
		-write $< $(TARGET) \
		-write LICENSE.txt license.txt,s \
		-write Makefile makefile,s \
		-write README.md readme.md,s \
		-write pfloph.c pfloph.c,s \
		$(foreach o,$(wildcard obj/*),-write $o $(notdir $o),u )\
		$(foreach s,$(wildcard src/*),-write $s $(notdir $s),s )

$(ERRDISKNAME).d64:	$(DISKNAME).d64 errappend$(BINEXT)
	cp -f $< $@
	./errappend$(BINEXT) $@

clean:
	rm -fr obj
	rm -f *.lbl *.map *.prg *.d64
	rm -f pfloph$(BINEXT) errappend$(BINEXT)

$(TARGET).prg:	$(OBJS) src/$(TARGET).cfg Makefile
	$(LD65) -o$@ $(LD65FLAGS) $(OBJS)

pfloph$(BINEXT):	pfloph.c Makefile
	$(CC) -o$@ $(CFLAGS) $<
	$(STRIP) $@

errappend$(BINEXT):	errappend.c Makefile
	$(CC) -o$@ $(CFLAGS) $<

obj/%.o:	src/%.s src/$(TARGET).cfg Makefile | obj
	$(CA65) $(CA65FLAGS) -o$@ $<

obj:
		mkdir obj

.PHONY:		all disk errdisk clean
