SRC=src/

CC=ivyc
CFLAGS=target=test
TOPFILE=server.ivy

LCH=ivy_launch
LCHFLAGS=node.max=1
EXE=server

CHK=ivy_check
CHKFLAGS=isolate=this

.PHONY: all clean test bmc

all: $(SRC)$(EXE) test bmc

$(SRC)$(EXE): $(SRC)$(TOPFILE)
	cd $(SRC); $(CC) $(CFLAGS) $(TOPFILE)

test: $(SRC)$(EXE)
	cd $(SRC); $(LCH) $(LCHFLAGS) $(EXE)

bmc: $(SRC)$(TOPFILE)
	cd $(SRC); $(CHK) $(CHKFLAGS) $(TOPFILE)

clean:
	./ivy_clean.sh
