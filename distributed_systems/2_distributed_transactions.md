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

### Optimistic Concurrency Control (OCC)

Optimistic concurrency control (OCC) is a concurrency control method that was first proposed in 1981 by Kung et al., where transactions can access data items without acquiring locks on them.

In this method, transactions execute in the following three phases:
- Begin. Transactions are assigned a unique timestamp
- Read & modify. Transactions execute their read and write operations tentatively. This means that when an item is modified, a copy of the item is written to a temporary, local storage location. A read operation first checks for a copy of the item in this location and returns this one, if it exists. Otherwise, it performs a regular read operation from the database.
- Validate & commit/rollback. The transaction checks whether there are other transactions that have modified the data this transaction has accessed, and have started after this transaction’s start time. If there are, then the transaction is aborted and restarted from the beginning, acquiring a new timestamp. Otherwise, the transaction can be committed.

### Achieving Snapshot Isolation

**Multiversion Concurrency Control (MVCC)** is a technique where multiple physical versions are maintained for a single logical data item. As a result, update operations do not overwrite existing records, but they write a new version of these records. Read operations can then select a specific version of a record, possibly an older one. This is in contrast with the previous techniques, where updates are performed in place and there is a single record for each data item that can be accessed by read operations.

In practice, MVCC is commonly used to implement the **snapshot isolation level**.

The idea of **Snapshot isolation** is that each transaction reads from a *consistent snapshot* of the database that is, the transaction sees all the data that was committed in the database at the start of the transaction. Even if the data is subsequently changed by another transaction, each transaction sees only the old data from that particular point in time.

This works in the following way:
- Each transaction is assigned a unique timestamp at the beginning.
- Every entry for a data item contains a version that corresponds to the timestamp of the transaction that created this new version.
- Every transaction records the following pieces of information during its beginning:
  - The transaction with the highest timestamp that has committed so far (say, Ts)
  - The number of active transactions that have started but haven’t been committed yet

### Achieving Full Serializable Snapshot Isolation

**Serializable Snapshot Isolation (SSI)** is an enhanced version of **Snapshot Isolation (SI)** that ensures **serializable execution** of transactions.  

It uses **MVCC** to give each transaction a **snapshot** of the database, allowing **reads without locks**. Unlike basic SI, which can lead to anomalies (e.g., **write skew**), SSI tracks **dependencies** between transactions and **detects conflicts** during execution or at **commit time**.  

If a conflict is found, one of the transactions is **aborted** to maintain **serializable consistency**—ensuring the result is equivalent to transactions running **one-by-one (serially)**.  

This approach combines **performance** and **strong consistency** without the overhead of **locking mechanisms**.

## Achieving Atomicity

### Hard to guarantee Atomicity

One common way of achieving atomicity, in this case, is through *journalling* or *write-ahead logging*. In this technique, metadata about the operation are first written to a separate file, along with markers that denote whether an operation has been completed or not. Based on this data, the system can identify which operations were in progress when a failure happened, and drive them to completion either by undoing their effects and aborting them, or by completing the remaining part and committing them. This approach is used extensively in file systems and databases.

The issue of atomicity in a distributed system becomes even more complicated because components (nodes in this context) are separated by the network that is slow and unreliable. Furthermore, we do not only need to make sure that an operation is performed atomically in a node. In most cases, we need to ensure that an operation is performed atomically across multiple nodes. This means that the operation needs to take effect either at all the nodes or at none of them. This problem is also known as atomic commit.

### 2-Phase Commit (2PC)

**2-Phase Commit (2PC)** is a **protocol** used in distributed systems to ensure that all participating nodes in a transaction **either commit or abort** changes, maintaining **atomicity** and **consistency**.  

**How it Works:**  
1. **Phase 1 - Prepare:**  
   - The **coordinator** asks all participants if they can **commit**. Each participant responds **Yes** (ready) or **No** (abort).  

2. **Phase 2 - Commit/Abort:**  
   - If **all say Yes**, the coordinator sends a **commit** command.  
   - If **any say No**, the coordinator sends an **abort** command.  

This guarantees that **all nodes agree** to commit or roll back, ensuring the **transaction is atomic** across the system.

📌 **Conclusion**: The 2PC protocol satisfies the safety property that ensures all participants always arrive at the same decision (atomicity). However, it does not satisfy the liveness property that implies it will always make progress.

### 3-Phase Commit (3PC)

The main bottleneck of the 2-phase commit protocol was failures of the coordinator leading the system to a blocked state.
The 2-phase commit problem could be tackled by splitting the first round (voting phase) into 2 sub-rounds, where the coordinator first communicates the votes result to the nodes, waits for an acknowledgment, and then proceeds with the commit or abort message. In this case, the participants would know the result from the votes and complete the protocol independently in case of a coordinator failure.

The main benefit of this protocol is that the coordinator stops being a single point of failure. In case of a coordinator failure, the participants are able to take over and complete the protocol. As a result, the 3PC protocol increases availability and prevents the coordinator from being a single point of failure.

However, this comes at the cost of correctness, since the protocol is vulnerable to failures such as network partitions.

📌 **Conclusion**: The 3PC protocol satisfies the liveness property that ensures it will always make progress, at the cost of violating the safety property of atomicity.

### Quorum-Based Commit Protocol

The main issue with the 3PC protocol occurs at the end of the second phase, where a potential network partition can bring the system to an inconsistent state. This can happen when participants attempt to unblock the protocol by taking the lead without having a picture of the overall system, resulting in a split-brain situation.

A Quorum-Based Commit Protocol is a method used in distributed systems to ensure that a transaction is committed only if a majority (quorum) of the nodes agree to proceed. 

This protocol leverages the concept of a quorum to ensure that different sides of a partition do not arrive at conflicting results.

A node can proceed with committing only if a commit quorum has been formed, while a node can proceed with aborting only if an abort quorum has been formed.

Based on the fact that a node can be in only one of the two quorums, it’s impossible for both quorums to be formed at two different sides of the partition and lead to conflicting results.

A **Quorum-Based Commit Protocol** is a method used in distributed systems to ensure that a transaction is **committed** only if a **majority (quorum)** of the nodes **agree** to proceed.  

**How it Works (Simple Steps):**  
1. **Propose Commit:**  
   - The coordinator sends a **request** to all participating nodes, asking if they are ready to **commit** the transaction.  

2. **Vote and Count Responses:**  
   - Each node **votes** either **Yes** (ready) or **No** (abort).  
   - The coordinator waits for votes and checks if a **quorum** (more than half) has **agreed** to commit.  

3. **Commit or Abort:**  
   - If a **quorum agrees**, the transaction is **committed**.  
   - Otherwise, the transaction is **aborted**.  

**Key Features:**
- **Majority Rule:** Only needs a **quorum** (e.g., 3 out of 5 nodes) to make progress, even if some nodes **fail**.  
- **Fault Tolerance:** Can **continue working** as long as the quorum is available, even during partial failures.  
- **Faster than 2PC/3PC:** No need for all nodes to respond—just a majority.  

**Example:**
- 5 nodes in a system.  
- Coordinator sends a commit request.  
- 3 nodes reply **Yes**, and 2 reply **No**.  
- Since **3 out of 5** form a **quorum**, the transaction is **committed**.  

**When to Use:**
- Suitable for **distributed databases** or systems where **availability** is more important than **strict consistency** (e.g., NoSQL databases like Cassandra).