CA65?=		ca65
LD65?=		ld65

CA65FLAGS+=	-t none -g
LD65FLAGS+=	-Ln $(TARGET).lbl -m $(TARGET).map -C src/$(TARGET).cfg

TARGET=		floph

MODULES=	main drv

OBJS=		$(addprefix obj/,$(addsuffix .o,$(MODULES)))

all:		$(TARGET).prg

clean:
		rm -fr obj
		rm *.lbl *.map *.prg

$(TARGET).prg:	$(OBJS) src/$(TARGET).cfg Makefile
	$(LD65) -o$@ $(LD65FLAGS) $(OBJS)

obj/%.o:	src/%.s src/$(TARGET).cfg Makefile | obj
	$(CA65) $(CA65FLAGS) -o$@ $<

obj:
		mkdir obj

.PHONY:		all clean
