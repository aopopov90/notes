# Understanding Distributed Transactions

## Distributed transactions

One of the most common problems faced when moving from a centralized to a distributed system is performing operations across multiple nodes in an atomic way. We call this a **distributed transaction**.

**Transaction** - is a unit of work performed in a database system that represents a change potentially composed of multiple operations. Database transactions are an abstraction invented to simplify engineers’ work and relieve them of dealing with all the possible failures that the inherent unreliability of hardware introduces.

**Distributed transaction** - is a transaction that takes place in two or more different nodes.

There are two slightly different variants of distributed transactions:
- The first variant is one where the same piece of data needs to be updated in multiple replicas. This is the case where the whole database is essentially duplicated in multiple nodes, and a transaction needs to update all of them in an atomic way.
- The second variant is one where different pieces of data that reside in different nodes need to be updated atomically. For instance, a financial application may use a partitioned database for the accounts of customers, where the balance of user A resides in node n1. In contrast, the balance of user B resides in node n2, and we want to transfer some money from user A to user B. We need to do this in an atomic way so that data is not lost (i.e., removed from user A, but not added in user B, because the transaction fails midway).

Note: The second variant is the most common use of distributed transactions, while primary-backup synchronous replication mostly tackles the first variant.

## Atomicity and isolation in distributed transactions

*Consistency* and *durability* do not require special treatment in distributed systems and are relatively straightforward. 
The aspects of *atomicity* and *isolation* are significantly more complex and require us to consider more things in the context of distributed transactions.

For instance, partial failures make it much harder to guarantee atomicity. Meanwhile, the concurrency and network asynchrony present in distributed systems make it challenging to preserve isolation between transactions running in different nodes.
Furthermore, atomicity and isolation have far-reaching implications for the performance and the availability of a distributed system

## Achieving Isolation

### Achieving serializability

There are some potential anomalies from concurrent transactions that are not properly isolated. There are different isolation levels that prevent these anomalies. Stronger isolation levels prevent more anomalies at the cost of performance.

**Strictly serializable** is the strongest isolation level. Then comes **serializability**.
A system that provides serializability guarantees that the result of any allowed execution of transactions is the same as that produced by some serial execution of the same transactions(hence its name).

Types of serializability:
- View serializability - very hard to calculate
- Conflict serializability - easier to calculate, widely used

A schedule is conflict serializable if it can be transformed into a serial schedule by swapping non-conflicting operations. Two operations conflict if:
- They are performed by different transactions.
- They access the same data item.
- At least one of them is a write operation.

As a result, we can have three different forms of conflicts:
- A read-write conflict
- A write-read conflict
- A write-write conflict

A practical way of determining whether a schedule is conflict serializable is through a **precedence graph**. A precedence graph is a directed graph, where the:
- Nodes represent transactions in a schedule
- Edges represent conflicts between operations

Generating a schedule that is serializable can be achieve in two basic ways:
- Prevent transactions from making progress when there is a risk of introducing a conflict that can create a cycle. This is **pessimistic** concurrency control. This is usually achieved by having transactions acquire locks on the data they process to prevent other transactions from processing the same data concurrently. The name pessimistic comes from the fact that this approach assumes that the majority of transactions are expected to conflict with each other, so appropriate measures are taken to prevent this from causing issues.
- Let transactions execute all their operations and check if committing that transaction could introduce a cycle. In that case, the transaction can be aborted and restarted from scratch. This is **optimistic** concurrency control.

In general, optimistic methods are expected to perform well in cases where there are not many conflicts between transactions. This can be the case for workloads with many read-only transactions and only a few write transactions, or in cases where most of the transactions touch different data.
Pessimistic methods incur some overhead from the use of locks. Still, they can perform better in workloads that contain a lot of transactions that conflict. This is because they reduce the number of aborts and restarts, thus reducing wasted effort.

Note: The main trade-off between pessimistic and optimistic concurrency control is between the extra overhead from locking mechanisms, and the wasted computation from aborted transactions.

### Pessimistic Concurrency Control (PCC)

**2-phase locking (2PL)** is a pessimistic concurrency control protocol that uses locks to prevent concurrent transactions from interfering. These locks indicate that a record is being used by a transaction, so that other transactions can determine whether it is safe to use it or not.

Two types of locks in 2PL:
- **Write (exclusive) locks**: These locks are acquired when a record is going to be written (inserted/updated/deleted).
- **Read (shared) locks**: These locks are acquired when a record is read.

Interaction between write (exclusive) locks and read (shared) locks:
- A *read lock* does not block a *read* from another transaction. This is why it is also called shared because multiple read locks can be acquired at the same time.
- A *read lock* blocks a *write* from another transaction. The other transaction will have to wait until the read operation is completed and the read lock is released. Then, it will have to acquire a write lock and perform the write operation.
- A *write lock* blocks both *reads* and *writes* from other transactions, which is also the reason it’s also called exclusive. The other transactions will have to wait for the write operation to complete and the write lock to be released; then, they will attempt to acquire the proper lock and proceed.

In 2-phase locking protocol, transactions acquire and release locks in two distinct phases:
- **Expanding** phase: a transaction is allowed to only acquire locks, but not release any locks.
- **Shrinking** phase: a transaction is allowed to only release locks, but not acquire any locks.

The locking mechanism introduces the risk for **deadlocks**, where two transactions might wait on each other for the release of a lock, thus never making progress. This is shown in the following illustration.

Ways to deal with deadlocks:
- Prevention - this can be done if transactions know all the locks they need in advance and acquire them in an ordered way. This is typically done by the application since many databases support interactive transactions and are thus unaware of all the data a transaction will access.
- Detection - aborting one of the transactions. Typically done by a database.