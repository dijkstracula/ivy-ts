# Failover

For our commit strategy to work, we need a manager that is able to detect
failures and send new views to all current servers. These views contain the
current set of active servers.  Our servers only wait for acknowledgements from
servers that are in the current view. This
guarantees that we progress through our protocol and are never deadlocked. 

To implement this manager, we use an instance of multi-paxos inside of our
manager process that handles consensus decisions for new views.

We may have been able to implement all of this functionality in the servers
themselves, i.e.  keeping track of current participants and sending out new
views, but we decided that it would be easier to have a single manager process
that handles all of this.

## Nascent server bootstrapping

New nodes may join the tuplespace by making their presence known to the
manager, who will add them a new view and inform all servers of that node's
presences.

Before that node can start participating, however, it needs an up-to-date copy
of all tuples in the tuplespace.  This will be bulk-transferred from another
node chosen by the manager; however, we need to ensure that no mutations make
the in-transit copy of the tuplespace invalid while it is being transferred.
We take a heavy-hammer approach here: The manager will ask all nodes to _park_
any asynchronous operations: local reads may still be served, but inserts and
removes must be delayed until the node is bootstrapped at the expense of tail
latencies.

To park a tuplespace server is to drain it of active requests; it will ACK back
either immediately if no request is in flight, or after that request is
finished.  When all ACKs come back, the manager knows that the whole network is
quiescent and may proceed with the bulk transfer.  Upon completion, nodes are
unparked and asynchronous operations may continue.

## Node termination

The manager uses a hypothetical "ideal failure detector" implemented as an
external action to decide when to terminate a node.  That node is removed
from the view; an "undead node" is handled gracefully by allowing itself to
finish any concurrent operation before transitioning to the killed state.
