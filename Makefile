
SRCDIR=src/
TOPLVLSRC=server.ivy
SRCS=$(TOPLVLSRC) utils.ivy tablet.ivy manager.ivy

CC=ivyc
CFLAGS=target=test

LCH=ivy_launch
LCHFLAGS=node.max=2 iters=10000
EXE=server

CHK=ivy_check
CHKFLAGS=isolate=this detailed=false

.PHONY: all build clean test bmc

all: build test bmc

build: $(SRCDIR)$(EXE)

$(SRCDIR)$(EXE): $(addprefix $(SRCDIR), $(SRCS))
	cd $(SRCDIR); $(CC) $(CFLAGS) $(notdir $<)

test: build
	cd $(SRCDIR); $(LCH) $(LCHFLAGS) $(EXE) #| sed -e '/{/,/}$$/ d'

bmc:
	cd $(SRCDIR); $(CHK) $(CHKFLAGS) tablet.ivy

clean:
	./scripts/ivy_clean.sh
