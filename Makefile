
SRCDIR=src/
TOPLVLSRC=server.ivy
SRCS=$(TOPLVLSRC) ts_types.ivy tablet.ivy manager.ivy

CC=ivyc
CFLAGS=target=test

LCH=ivy_launch
LCHFLAGS=node.max=1
EXE=server

CHK=ivy_check
CHKFLAGS=isolate=this detailed=false

.PHONY: all build clean test bmc

all: build test bmc

build: $(SRCDIR)$(EXE)

$(SRCDIR)$(EXE): $(addprefix $(SRCDIR), $(SRCS))
	cd $(SRCDIR); $(CC) $(CFLAGS) $(notdir $<)

test: build
	cd $(SRCDIR); $(LCH) $(LCHFLAGS) $(EXE)

bmc: build
	cd $(SRCDIR); $(CHK) $(CHKFLAGS) $(TOPLVLSRC)

clean:
	./scripts/ivy_clean.sh
