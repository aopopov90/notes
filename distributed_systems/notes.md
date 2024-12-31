# Introduction

## System models

A *synchronous* system is one where each node has an accurate clock, and there is a known upper bound on the message transmission delay and processing time. As a result, the execution is split into rounds. This way, every node sends a message to another node, the messages deliver, and every node computes based on the messages it receives. During this, all nodes run in lock-step.

An *asynchronous* system is one where there is no fixed upper bound on how long it takes for a node to deliver a message, or how much time elapses between consecutive steps of a node. The system nodes do not have a common notion of time and, thus, run at independent rates.

## Types of Failure

4 types:
- Fail-stop. A node halts and remains halted permanently. Other nodes can detect that the node has failed (i.e., by communicating with it).
- Crash. A node halts, but silently. So, other nodes may not be able to detect this state. They can only assume its failure when they are unable to communicate with it.
- Omission. A node fails to respond to incoming requests.
- Byzantine. A node exhibits arbitrary behavior: it may transmit arbitrary messages at arbitrary times, take incorrect steps, or stop. Byzantine failures occur when a node does not behave according to its specific protocol or algorithm. This usually happens when a malicious actor or a software bug compromises the node.

Fail-stop failures are the simplest and the most convenient ones from the perspective of someone that builds distributed systems. However, they are not very realistic. This is because there are many cases in real-life systems where it’s not easy for us to identify whether another node crashes or not.

## The Tale of Exactly-Once Semantics

Network failures can lead to multiple deliveries of a message which can lead to catastrophic results (e.g. money transfer).

Possible approaches to ensures that nodes process a message only once:
- *Idempotent* operations approach - Idempotent is an operation we can apply multiple times without changing the result beyond the initial application. Example - adding values to a set. Even if we apply this operation multiple times, the operations that run after the first will have no effect, since the value will already be added to the set. An example of a non-idempotent operation is to increase a counter by one, where the operation will have additional side effects every time it’s applied. However, idempotent operations commonly impose tight constraints on the system.
- *De-duplication* approach. In the de-duplication approach, we give every message a unique identifier, and every retried message contains the same identifier as the original. In this way, the recipient can remember the set of identifiers it received and executed already. It will also avoid executing operations that are executed. We must have control on both sides: sender and receiver. Example: emails.

It is important to distinguish between *delivery* and *processing*:
- Delivery - arrival of a message at a hardware level
- Processing - handing of a message from the software application level

It’s impossible to have exactly-once delivery in a distributed system. However, it’s still sometimes possible to have exactly-once processing.

## Failure in the World of Distributed Systems

### Timeouts

The asynchronous nature of the network in a distributed system can make it very hard for us to differentiate between a crashed node and a node that is just really slow to respond to requests.
Timeouts is the main mechanism we can use to detect failures in distributed systems. Since an asynchronous network can infinitely delay messages, timeouts impose an artificial upper bound on these delays.

Trade-offs:
- If we select a smaller value for the timeout, our system will waste less time waiting for the nodes that have crashed. At the same time, the system might declare some nodes that have not crashed dead, while they are actually just a bit slower than expected.
- If we select a larger value for the timeout, the system will be more lenient with slow nodes. At the same time, the system will be slower in identifying crashed nodes, in some cases wasting time while waiting for them.

### Failure detector

A failure detector is the component of a node that we can use to identify other nodes that have failed.

We can distinguish the different categories of failure detectors through two basic properties that reflect the trade-off:
- Completeness corresponds to the percentage of crashed nodes a failure detector successfully identifies in a certain period.
- Accuracy corresponds to the number of mistakes a failure detector makes in a certain period.

A perfect failure detector is the one with the strongest form of completeness and accuracy. That is, it is one that successfully detects every faulty process without ever assuming a node has crashed before it actually does.
As expected, it is impossible to build a perfect failure detector in purely asynchronous systems. Still, we can even use imperfect failure detectors to solve difficult problems. One such example is the problem of consensus.

## Stateless and Stateful Systems

A **stateless** system maintains no state of what happened in the past and performs its capabilities purely based on the inputs we provide to it.

**Stateful** systems are responsible for maintaining and mutating a state. Their results depend on this state.

Observations:
- Stateful systems are beneficial in real life because computers are much more capable than humans of storing and processing data.
- Maintaining state involves additional complexity. For example, we must decide what’s the most efficient way to store and process it, how to perform back-ups, etc.
- As a result, it’s usually wise to create an architecture that contains clear boundaries between stateless components (which perform business capabilities) and stateful components (which handle data).

Stateless distributed systems are much easier to design, build and scale, compared to stateful ones.

The main reason for this is that we consider all the nodes (e.g., servers) of a stateless system identical. This makes it a lot easier for us to balance traffic between them, and scale by adding or removing servers.

However, stateful systems present many more challenges. As different nodes can hold different pieces of data, they require additional work. They need to direct traffic to the right place and ensure each instance is in sync with the others.

# Core concepts and theoretical foundations

## Partitioning

Partitioning is the process of splitting a dataset into multiple, smaller datasets, and then assigning the responsibility of storing and processing them to different nodes of a distributed system. This allows us to add more nodes to our system and increase the size of the data it can handle.

There are two different variations of partitioning:
- Vertical partitioning
- Horizontal partitioning (or **sharding**)

### Vertical

Vertical partitioning involves splitting a table into multiple tables with fewer columns and using additional tables to store columns that relate rows across tables. We commonly refer to this as a join operation. We can then store these different tables in different nodes.

Normalization is one way to perform vertical partitioning. However, general vertical partitioning goes far beyond that: it splits a column, even when they are normalized.

### Horizontal

Horizontal partitioning involves splitting a table into multiple, smaller tables, where each table contains a percentage of the initial table’s rows. We can then store these different subtables in different nodes.

Vertical partitioning is mainly a data modeling practice, which can be performed by the engineers designing a system—sometimes independently of the storage systems used. However, horizontal partitioning is a common feature of distributed databases. 


## Algorithms for Horizontal Partitioning

Some algorithms:
- Range partitioning (map nodes to specific ranges)
- Hash partitioning (e.g. assign based on the function hash(s) mod n)
- Consistent hashing (ring based)

## Replication

Replication - is a technique used to achieve availability. It consists of storing the same piece of data in multiple nodes (called replicas) so that if one of them crashes, data is not lost, and requests can be served from the other nodes in the meanwhile.
Availability - ability of the system to remain functional despite failures in parts of it.

Engineers sometimes willingly accept a system that provides much higher performance, but occasionally gives an inconsistent view of the data. Therefore, there are two main strategies for replication:
1. **Pessimistic** replication. Tries to guarantee from the beginning that all the replicas are identical to each other.
2. **Optimistic** replication (or lazy). Allows replicas to diverge. This guarantees that they will converge again if the system does not receive any updates, or enters a quiesced state, for a period of time.

## Primary-Backup Replication Algorithm

This is a technique where we designate a single node amongst the replicas as the leader, or primary, that receives all the updates. We commonly refer to the remaining replicas as followers or secondaries. These can only handle read requests. Every time the leader receives an update, it executes it locally and also propagates the update to the other nodes. This ensures that all the replicas maintain a consistent view of the data.

There are two ways to propagate the updates:
1. **Syncronous**: the node replies to the client to indicate the update is complete—only after receiving acknowledgments from the other replicas that they’ve also performed the update on their local storage. This also ensures consistency and durability. However, the technique can make writing requests slower. This is because the leader has to wait until it receives responses from all the replicas.
2. **Asyncronous**: the node replies to the client as soon as it performs the update in its local storage, without waiting for responses from the other replicas. This technique increases performance significantly for write requests. However, this comes at the cost of reduced consistency and decreased durability.

## Multi-Primary Replication Algorithm

Primary-backup replication has some limitations in terms of performance, scalability, and availability.

There are many applications where availability and performance are much more important than data consistency or transactional semantics. For example, a shopping cart where a customer can resolve conflicts at checkout.

Multi-primary replication is an alternative replication technique that favors higher availability and performance over data consistency. In this technique, all replicas are equal and can accept write requests. They are also responsible for propagating the data modifications to the rest of the group. This can lead to conflicts. Conflict resolution approaches:
- **Eagerly**: the conflict is resolved during the write operation.
- **Lazily**: the write operation proceeds to maintain multiple, alternative versions of the data record that are eventually resolved to a single version later on, i.e., during a subsequent read operation.

## Quorums in Distributed Systems

The problem with syncronous replication is that availability for write operations is low,  because the failure of a single node makes the system unable to process writes until the node recovers.
To solve this problem, we can use the reverse strategy. That is, we write data only to the node that is responsible for processing a write operation, but process read operations by reading from all the nodes and returning the latest value.

This increases the availability of writes significantly but decreases the availability of reads at the same time. So, we have a trade-off that needs a mechanism to achieve a balance. Let’s see that mechanism. A useful mechanism to achieve a balance in this trade-off is to use quorums.

## Safety Guarantees in Distributed Systems

The main safety guarantors are around the three properties:
1. Atomicity - is challenging to achieve due to **partial failures**
2. Isolation - is challenging to achieve due to **network asynchrony**
3. Consistency - is challenging to achieve due to inherent **concurrency**

## ACID Transactions

ACID is a set of properties of traditional database transactions that provide guarantees around the expected behavior of transactions during errors, power failures, etc. More specifically, these properties are the following:
1. Atomicity. Guarantees that a transaction that comprises multiple operations is treated as a single unit. This means that either all operations of the transaction are executed or none of them are.
2. Consistency. ensures that a database remains in a valid state before and after a transaction, preserving all rules and constraints.
3. Isolation. Guarantees that even though transactions might run concurrently and have data dependencies, the result is as if one of them was executed at a time and there was no interference between them.
4. Durability. Guarantees that once a transaction is committed, it remains committed even in the case of failure.

## The CAP Theorem

The CAP Theorem is one of the most fundamental theorems in the field of distributed systems. It outlines an inherent trade-off in the design of distributed systems.

**Consistency** means that every successful read request receives the result of the most recent write request.
**Availability** means that every request receives a non-error response, without any guarantees on whether it reflects the most recent write request.
**Partition tolerance** means that the system can continue to operate despite an arbitrary number of messages being dropped by the network between nodes due to a network partition. A network partition refers to a situation where the nodes in a distributed system are split into isolated groups that can no longer communicate with each other due to network failures. This is a common scenario in distributed systems, where network links might go down, causing some nodes to lose connectivity with others.

Initial statement: it is impossible for a distributed data store to provide more than two of the following properties simultaneously: consistency, availability, and partition tolerance.

In a distributed system, there is always the risk of a network partition. If this happens, the system needs to decide either to continue operating and compromise data consistency, or stop operating and compromise availability.
However, there is no such thing as trading off partition tolerance to maintain both consistency and availability. As a result, what this theorem really states is the following.

Revised statement: a distributed system can be either consistent or available in the presence of a network partition.

The **PACELC theorem** is an extension of the CAP theorem: “In the case of a network partition (P), the system has to choose between availability (A) and consistency (C) but else (E), when the system operates normally in the absence of network partitions, the system has to choose between latency (L) and consistency (C).”

These sub-categories are combined to form the following four categories:
- AP/EL
- CP/EL
- AP/EC
- CP/EC