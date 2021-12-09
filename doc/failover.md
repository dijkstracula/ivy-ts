# Failover
For our commit strategy to work, we need a manager that is able to detect failures and
send new views to all current servers. These views contain the current set of active servers.
Our servers only wait for acknowledgements from servers that are in the current view. This
guarantees that we progress through our protocol and are never deadlocked. 

To implement this manager, we use an instance of multi-paxos inside of our manager process
that handles consensus decisions for new views.

We may have been able to implement all of this functionality in the servers themselves, i.e.
keeping track of current participants and sending out new views, but we decided that it
would be easier to have a single manager process that handles all of this.

## Nascent server bootstrapping

New nodes may join the tuplespace by making their presence known to the
manager, who will add them a new view and inform all servers of that node's
presences.

When a new server spins up, it needs to bootstrap its copy of the tuplespace
from an existing server.  It'll choose one in the view and have it replicate
its tablet over (retrying if that node in the view is, itself, getting data
replicated over too).  The problem is this:  other nodes, which may have no
idea yet of the new server, may be concurrently mutating the tablet.

We can know that the new view message has gone out at least.  But, that will be
over the `man_net` overlay network which can be arbitrarily delayed vs
insert/delete messages on the other overlay network.  So what happens if:

1) Nascent node asks replicating node for its tuples
2) Replicating node sends its tuples over
3) Inserting node broadcasts insert to the replicating node and commits
4) Inserting node is informed of the new view, but the nascent node is missing the insert

Does insert need to be a 2PC, too?  I don't even know if that's enough:
consider a tuple removal, where both marking and removal happens in step 3 of
the above.

Is the thing we want, morally, the tuple snapshot + "snapshot of all in-flight
messages to that node"?  

Do we need ACKs back on new views?  Or at minimum telling the manager "node 0,
copy your state over to node n+1"?
