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
produce the _same_ tuple depending on networking timing and message arrival.
Concretely, however, once a tuple has been marked for extraction as part of
`remove`'s 2PC protocol (see below), our implementation will treat that tuple
as absent for reading.

However, this does mean that in the case of a read concurrent with a 2PC rollback,
the tuple may be observed to disappear and then reappear.  TODO: pretty sure this
breaks causal consistency; is it as straightforward to simply ignore the `mark`
field on a sloppy causal read?  

## Tuple write

### IPC messages:

This operation requires communication with all other nodes:  The originating
process broadcasts a `server_store_req`, which, when received, will perform a local
write and reply with a `server_store_resp`.

### Commit point:

When all `server_store_resp` messages have been received from our current view.

## Tuple extraction

Extraction (the `remove` operation) is a slightly more involved protocol, since
we need to ensure mutual exclusion so only one tuple is removed by one process.
To do so, we perform a two-phase commit protocol and, potentially, a local read
to service such a request.

We first begin by fully materialising a tuple by doing a local read, "filling
in the blanks" of any wildcards as necessary.  The result of this read operation
gives us the concrete tuple to remove from the system. Then, we do the
following two-phase protocol:

### 1. Hold acquisition

A `tuple_lock_req` message is sent in-order to all nodes, where nodes will mark
the tuple in question with a flag indicating it is being held as part of an
extraction operation.  To mark a tuple is to promise not to allow anyone else
to hold it.

A response message is sent back with whether or not we successfully took the
lock, by which we mean "were we able to mark the tuple" or, in the case of
retries, "did we mark the tuple already?"

If we fail to mark a tuple on any node, we know that must be because someone
else is farther along than us, so we have to retry. 

(TODO: this means both processes would back off.  Is there a way to
deterministically choose who backs off??  higher node ID overwrites a mark and
the lower ID continues?  Seems dangerous but worth thinking about.)

Notice that a given node might not have the tuple to hold - consider a case
where a write is slow to be received and we receive the acquisition message
first!  In this case, we should implicitly store the tuple and leave it locked;
this is safe because writes here are idempotent and so when the write
ultimately arrives it will be an effective no-op.  (TODO: I forgot to implement
this)

### 2. Deletion

If we succeed in taking the hold on all nodes, we can then broadcast out the
`delete` message, which actually removes the tuple from the tuplespace.  Once
we get `resp`s back, we can hand the tuple back to the client.

## Rollback

Before we can retry an extraction we need to unmark all the nodes we previously
marked.  We broadcast a `tuple_undo_mark_req` message to all such nodes and then
wait for responses before retrying.

### Commit point:

When all `tuple_delete_resp` messages have been received from our current view.
