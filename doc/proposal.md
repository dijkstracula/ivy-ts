# CS 395T Course Project

## Team logistics

Cole Vick and I will work on this project together!

## Overview

For my course project, we'd like to implement a scalable key-value store that
imitates distributed shared memory in the form of a [Linda-style tuple
space](https://wiki.c2.com/?TupleSpace), and a subset of the standard
operations that operate upon it.

A tuple space is, in essence, a sharded and replicated bag of sequences of
values that clients can concurrently access and mutate.  Tuples are
content-addressible rather than keyed on some GUID, but apart from that the
core API to a tuple space closely resembles a CRUD-style get/put interface.  

However, a tuple space's read operation is richer than just a get and is more
akin to a `SELECT LIMIT 1` in SQL: clients can either specify a value for every
key in the tuple (yielding a value only when an exact match is found) or by
leaving certain fields in the key blank, an arbitrary match satisfying all
concrete keys are produced.  Tuple space APIs, therefore, map well to
programming languages where pattern matching is exposed as as first-class
construct (which IVy is not!).

Consider a hypothetical ping-pong service in a hypothetical language:

```
;; In a traditional Linda, `in` operations block until a matching tuple has
;; been inserted by another client.  In Ivy, they will probably return a NACK
;; if no match is found.  In that case, the client could imagine implementing
;; some sort of backoff policy before retrying.
(define (ping-service)
  (define (iter i)
    (tuplespace-out (list 'ping i)) ;; Write the ith ping into the tuplespace
    (tuplespace-in  (list 'pong i)) ;; Select the corresponding pong out of the tuplespace
    (iter (+ 1 i)))
  (iter 0))

;; Let's use the convention that atoms prefaced with a `?` are pattern
;; variables which will have values bound to them by the callee.
(define (pong-service)
  (tuplespace-in  (list 'ping ?i)) ;; Select the ith ping from the tuplespace, binding its cadr to i
  (tuplespace-out (list 'pong ?i)) ;; Write the corresponding pong back into the tuplespace
  (pong-service))

;; Concurrently with the ping and pong operations, read any inserted but not yet
;; removed elements.
(define (observer-service)
  (let (v (tuplespace-rd (list ?op ?i))) ;; Read (but do not extract) an arbitrary tuple
       (if (not (some? v))
           (write "An element in the tuple space is: " v)))
  (observer-service))
```

Note that in the above example's pong service, had we used a pattern variable
for the first element in the tuple, then the runtime may have either handed
back a ping _or_ a pong tuple, which could potentially deadlock the system.

## Consistency model

The consistency model for our tuplespace implementation supports both
linearizable and non-linearizable operations:

* `out`: Inserts a tuple into the tuplespace.
* `in`: Extracts (i.e. reads and atomically removes) an element from the tuplespace.
* `rd`: Reads (but does not remove) an element from the tuplespace.

Since the tuple-space is content-addressable, multiple concurrent `out`
operations inserting the same key are idempotent.  By contrast, multiple
concurrent `in` operations are different: at most one such operation needs
to succeed to preserve the notion of an atomic removal.

The `rd` operation bypasses the strong consistency semantics of `in`.
Therefore, application developers must be aware that concurrent `rd` and `in`
operations may return the same tuple if the removal by the latter was not
observed by the former.  In this sense, `rd` supports only causal consistency.

## Sharding and data access

One trivial way to achieve replication of tuples is for each node in the
tuplespace to store a complete copy of the whole space (i.e. an `out` operation
is a broadcast to all nodes).  This makes queries involving wildcards trivial
(since all nodes will have a copy of a tuple), but complicates atomic
extraction operations.  Another trivial way is to simply associate a single
tuple with a single key hash and replicate in a ring in the Dynamo style.
Here the tradeoff is complementary: if (modulo failover) exactly one node
serves reads, atomic removal is straightforward; however, _finding_ a given
tuple given a wildcard search becomes problematic.

We propose a middle-ground of the two that hopefully simplifies both extraction
and wildcarded lookups:

In our scheme, we multicast an `out` operation on an n-ary tuple to (at most) `n
nodes.  The indexes of the nodes are chosen according to the hashes of the `n`
componentjs of the tuple.

For example, inserting the tuple `'(a b c)` requires hashing the atoms `'a`,
`'b`, and `'c`.  If, say, those hashed to 0, 42, and 99, respectively, and
nodes 0, 2, and 3 covered those respective key hashes, then the entire `'(a b
c)` tuple is written to nodes 0, 2 and 3.

Notice that the permuted tuple `'(b c a)`, which is treated as a distinct
tuplespace element, would be replicated to exactly the same nodes;
additionally, the similar tuple `'(a z c)` would be replicated to nodes 0 and
3, and additionally whatever third host is responsible for `'z`'s hash, but not
node 2 (unless `'b` and `'z` happen to hash to the same value, of course).

A read operation can either be _complete_ or _wildcarded_.  In the case of a
complete read, by re-hashing the three components of the read we can re-derive
which storage hosts to communicate with (even if rebalancing has since
occurred).

In the case of a _wildcarded_ read, such as `'(a ?x c)`, we hash the two
non-wildcarded elements, yielding, in our case, nodes 0 and 3.  A request to 
_materialise_ this wildcarded tuple is then sent to one of those nodes, where
an "arbitary" matching tuple is produced as a result (in our example case,
either `'(a b c)` or `'(a z c)`, both of which are to be found on both nodes 0
and 3.)

Once a complete tuple has been materialised, it can be returned to the client
if a simple causal `rd` was made.  If this is part of an `in` operation, more
work needs to be done: suppose we arbitrarily had `'(a b c)` materialised: we
now need to multicast a remove message to nodes 0, 2, and 3 before we can
successfully tell the client which tuple we extracted.

TODO: The above feels a bit like 2PC.  Do we need to do something like
heavyweight?


## Architecture:

### Clients

Clients would like to operate on the tuplespace through the `in`, `out`, and
`rd` interface.  A key part of the client also involves marshalling requests
with wildcard syntax, which requires a bit of additional mechanism in IVy.

### Pattern matching syntax tranformer (stretch goal??)

The reliance on pattern matching yields a slight impedence mismatch with
IVy's language features.  If there's time: It'd also be fun to implement a bit
of preprocessing sugar to perform code transformations of the forms like:

a) removing the need to define tuples as all having optional fields (where a
`none` indicates a wildcard):

```
tuple {
    field type: pingpong_enum;
    field val: byte;
}

=>

class __tuple {
    field type : option[pingpong_enum];
    field val : option[byte];
}
```

b) Sugar for simple tuple destruction and name binding:

```
match msg.tuple as (pong_type, ?i) {
  debug "Received pong" with val=i;
}

=> 

if msg.tuple.type = some(pong_type) {
  val i : byte;
  i := msg.tuple.val;

  debug "Received pong" with val=i;
}
```

Or something like this!

Implementation is either as a preprocessing pass (pyparser? m4??) or by forking
the actual IVy parser for fun. 

### Manager

The manager is responsible for:

a) mapping hash values to current nodes (alternative: clients get new "shard views"?)
b) rebalancing of the keyspace when new nodes join and others die.
c) serialising ordering of "atomic remove" messages.

TODO: We'll be covering more advanced P2P-like protocols soon.  Is the Manager
functionality something that should be a distinct process like what we've seen with
Dynamo in class, or be built into the storage node?

### Storage node

Shard node: "I manage a range of hash values."
"I will receive a tuple (maybe with wildcard) that I might contain."

A trivial way to handle storage node lookups is by a simple O(n) table scan.
If we insert tuples in some lexiographic order, a complete query (or at least
up to some non-wildcarded prefix) can be done in logarithmic time.  We'd still
have to do a linear search for something like `'(? b c)` - this could be
addressed with something like a covering index if we really wanted to, but that
might be too much to do.

# Meeting notes 11/9/2021

- Look at CAMs (Ken will find a good citation) - they possibly allow
  wildcarding too?
- Be explicit about correctness condition for e.g. rd concurrent to in (seems like
  serializability); but, we'll have to generate the commit order.
- Think hard about deadlock avoidance!  Deterministic lock ordering, ensure locks
  are eventually unlocked
- Think about testing with both applications (e.g. dining philosophers?) as well
  as random protocol-level tests.
- Storage node: lookup isn't strictly interesting from a concurrency perspective
  so the dumbest matching algorithm (linear probe) is fine.
- Start with the linearizability specification at the level of top-level operations
