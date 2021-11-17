SRCDIR=src/
SRCS=server.ivy ts_types.ivy

CC=ivyc
CFLAGS=target=test

LCH=ivy_launch
LCHFLAGS=node.max=1
EXE=server

CHK=ivy_check
CHKFLAGS=isolate=this

.PHONY: all build clean test bmc

all: build test bmc

build: $(SRCDIR)$(EXE)

$(SRCDIR)$(EXE): $(addprefix $(SRCDIR), $(SRCS))
	cd $(SRCDIR); $(CC) $(CFLAGS) $(notdir $<)

test: $(SRCDIR)$(EXE)
	cd $(SRCDIR); $(LCH) $(LCHFLAGS) $(EXE)

bmc: $(SRCDIR)$(TOPFILE)
	cd $(SRCDIR); $(CHK) $(CHKFLAGS) $(TOPFILE)

clean:
	./ivy_clean.sh
