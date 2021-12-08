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

