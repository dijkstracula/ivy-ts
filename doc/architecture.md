# Architecture

# Tuplespace operations

The consistency model for our tuplespace implementation supports both
sequentially-consistent as well as weaker operations:

* `insert`: Inserts a tuple into the tuplespace.
* `remove`: Extracts (i.e. reads and atomically removes) an element from the tuplespace.
* `read`: Reads (but does not remove or otherwise modify) an element from the tuplespace.

Ivy-ts supports the three basic operations exposed by a tuplespace: tuple reads
and inserts, and at-most once atomic removal.  The input to a read or removal
operation may either be an exact tuple (which we'll refer to as a _point
read_), or a pattern which a stored tuple is unified against.

Since the tuple-space is content-addressable, multiple concurrent `insert`
operations inserting the same key are idempotent.  By contrast, multiple
concurrent `remove` operations are different: at most one such operation needs
to succeed to preserve the notion of an atomic removal.

The `read` operation bypasses the strong consistency semantics of `remove`.
Therefore, application developers must be aware that concurrent `read` and
`remove` operations may return the same tuple if the removal by the latter was
not observed by the former.  In this sense, `read` supports only causal
consistency.  A comparison might be drawn with executing a parallel program on
a shared multiprocessor machine, where programmers read a particular machine
word with both atomic and non-atomic instructions.

# Workload assumptions

Since tuplespaces form a sort of distributed shared memory, we assume access 
patterns to mimic that of a symmetric multiprocessing workload: shared tuples
are mostly read-only, with occasional inserts/updates, and infrequent atomic
removal operations.  Architectural decisions reflect this assumption.

## Sharding and replication

Tuples in a tuplespace have some characteristics which make them difficult
to shard and replicate in the usual manner.  That any and all tuple components
can be wildcarded means there isn't a single value that a stored tuple can be
hashed to that will match on all valid inputs.  

### Write-one, read all

In this scheme, writes only go to a single node, which could either be simply
local to the writing process, round-robin, or something fancier, but servicing
reads require a broadcast to all nodes.  Additionally, some notion of
replication needs to be baked in to ensure tuples are not lost if the owning
node fails, and a broadcast is required to rebalance the cluster of nodes when
a new node is brought online.

### Write-all, read one

In this scheme, writes are broadcast to all nodes resulting in a total
duplication of all tuples across all nodes, at the expense of cheap local
(non-removal) reads.

### Per-component indexing

An early proposal suggested hashing and storing each component independently,
where an n-ary tuple is stored on at most `n` nodes (chosen according to the
hash value of its individual components), and the first cut of the
implementation took this approach.  However, this scheme proved in practice to
have some unfortunate corner cases: in the worst case, a 1-tuple wouldn't be
replicated at all, nor would an n-ary tuple whose components happened to all
collide to the same server.  As a result, a separate replication layer would
be required (faulting in all the downsides of a _write-one, read-all_
strategy); however, in the case where the number of components in a tuple and
number of replicas is ~= sqrt(number of nodes), a write approaches a broadcast
to all nodes anyway except with more complicated replication and sharding
logic.

Based on our experience with per-index sharding, we chose to pivot from it to a
_write-all, read-one_ scheme, so that each server in the network is responsible
for storing all tuples in the tuplespace.  This results in common read
operations being cheap.

