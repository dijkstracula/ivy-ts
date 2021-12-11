# Project status and future work

The bulk of the core functionality is present and appears to be working.  The
core read, insert, and removal operations are implemented; additionally, with
the help of a hypothetical, external failure detector, the RSM manager is able
to remove dead nodes; additionally, we have some notion of nodes being able to
"join" the tuplespace by registering with the manager.

However, in some test runs we are able to see "temporary hangs" where Ivy
stalls for a moment or two before proceeding.  We hypothesize that this is
owing to the random tester discarding actions because of ghost preconditions.  

There remain, of course, things we could keep pushing on that would present new
verification challenges.

## Variadic tuple types

Currently all tuples have the same fixed type, a small bitvector type.  As a
result, clients need to manually map domain knowledge onto these types (i.e.
"a bit field of 0 indicates a 'fork pickup' and a bit field of 1 indicates
'fork putdown' for a dining-philosophers implementation), which is marginally
inconvenient.  Perhaps a real-world implementation would prefer a tuple to
be a user-defined structure type rather than a vector[bv[3]].

## Implement exec()

One missing primitive from the bog-standard tuplespace implementation is 
exec(), which spawns at runtime a new server.  

## Client module and RPC metaprotocol

The client is treated as part of the external environment which "calls into"
the server.  This is fine in terms of the distributed protocols; however,
contemplating user-programmability remains an important part of a "real"
implementation that we've not done here.

Lastly, implementing multi-round protocols with request/response subclasses
proved to be slightly tedious; it would have been interesting to use Ivy's
module system to implement an RPC metaprotocol in the style of lwt[1] or
Finagle[2].

[1] https://opam.ocaml.org/packages/lwt/
[2] https://monkey.org/~marius/funsrv.pdf
