# Tuplespace operations

Two of the three operations needed for a tuplespace implementation
require communication between nodes.

## Tuple read

### IPC messages:

None.  This operation can be performed entirely locally: all tuples are
replicated to all nodes, so if a tuple exists, the client's node will be able
to service the request.

### Commit point:

None.  Note that a read operation that is concurrent with an atomic removal may
produce the _same_ tuple.  We could ignore whether a tuple is in the midst of
being removed and not violate this "anything could happen" guarantee; however,
since a read is potentially part of the extraction operation, it's better to be
overly-picky and potentially NACK on a tuple that is being held but hasn't been
removed yet.

TODO: we could add a `ignore_held` flag but is probably overkill for this.

## Tuple write

### IPC messages:

This operation requires communication with all other nodes:  The originating
process broadcasts a `server_store_req`, which, when received, will perform a local
write and reply with a `server_store_resp`.

### Commit point:

When all nodes' `server_store_resp` messages have been received.

## Tuple extraction

Extraction is a slightly more involved protocol, since we need to ensure mutual
exclusion so only one tuple is removed by one process.  We first begin by fully
materialising a tuple by doing a local read, "filling in the blanks" of any wildcards
as necessary.  Then, we do the following two-phase protocol:

### 1. Hold acquisition

A `tuple_lock_req` message is sent in-order to all nodes, where nodes will mark
the tuple in question with as being held as part of an extraction operation.
To mark a tuple is to promise not to allow anyone else to hold it.

A response message is sent back with whether or not we successfully took the
lock.

Because we take holds in a deterministic order, if we fail to take a hold at some
point we know that must be because someone else is farther along than us, so we
have to retry. (TODO: with failover, is this necessarily true???  This might mean
that the view needs to also store the order that we will take holds for)

Notice that a given node might not have the tuple to hold - consider a case
where a write is slow to be received and we receive the acquisition message
first!  In this case, we should implicitly store the tuple and leave it locked;
this is safe because writes here are idempotent and so when the write
ultimately arrives it will be an effective no-op.

### 2. Deletion

If we succeed in taking the hold on all nodes, we can then broadcast out the
`delete` message, which actually removes the tuple from the tuplespace.  Once
we get `resp`s back, we can hand the tuple back to the client.


### Commit point:

When all nodes' `server_delete_resp` messages have been received.
