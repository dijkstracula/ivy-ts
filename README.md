```
    _                                                            _
   (_)                                                          (_)
 _______               ____               _                   _ (_) _   _   __________
(_, _, _)_           _(_, _)_           _(_)  _____________  (_, _, _) (_)_(_, _, _, _)
   (_)  (_)_       _(_)    (_)_       _(_)   (_, _, _, _, _)    (_)      (_)__________
   (_)    (_)_____(_)        (_)_____(_)                        (_)      _ (_, _, _, _)_
 _ (_) _    (_,_,_)            (_,_,_)                          (_)____ (_) __________(_)
(_, _, _)     (_)               _(_)                              (_)(_)   (_, _, _, _)
                           ____(_)
                          (_, _)
```

Tuplespaces in IVy

## Authors

* Nathan Taylor (`ntaylor@cs.utexas.edu`)
* Cole Vick (`cvick@cs.utexas.edu`)

## Documentation

```
doc/architecture.md ; High-level project structure
doc/operations.md   ; Client operations, consistency guarantees, pseudocode
doc/proposal.md     ; The submitted project proposal
```

## Setup:

You may wish to build a tagfile for your editor to consume ([Universal
Ctags](https://github.com/universal-ctags/ctags) required, and your
/path/to/ivy may vary):

```
$ ctags --options=./scripts/ivy.ctags -L<(find ~/code/ivy/ivy/include/1.8/)
$ ctags --options=./scripts/ivy.ctags --append -R
```

## Building and Running:

```
$ make build ; transpile to C++
$ make test  ; random testing
$ make bmc   ; run BMC

$ make       ; all of the above
```
