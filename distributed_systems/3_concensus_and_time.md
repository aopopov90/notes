# Consensus and Time in Distributed Systems

## Consensus

Many problems in distributed systems involve nodes reaching agreement on a specific value or state, such as whether a transaction is committed or a message is delivered. This fundamental challenge is called the **consensus problem**.  

**Consensus Problem Definition:**  
Given a set of nodes, each proposing a value, consensus ensures:  
1. **Termination** – Every non-faulty node eventually decides.  
2. **Agreement** – All non-faulty nodes make the same decision.  
3. **Validity** – The agreed value must have been proposed by a node.  

**Use Cases of Consensus:**  
1. **Leader Election** – Nodes elect a leader to coordinate operations, e.g., primary-backup replication, modeled as consensus on the leader’s identity.  
2. **Distributed Locking** – Nodes agree on which node holds a lock to manage concurrency, preventing inconsistencies.  
3. **Atomic Broadcast** – Ensures all nodes deliver messages in the same order, despite faults, maintaining consistency.  

**Key Insight:**  
Consensus serves as a **building block** for solving many distributed system problems by enabling nodes to agree reliably, even in the presence of faults. Solving consensus simplifies the design of more complex distributed algorithms.

## FLP Impossibility

The **FLP Impossibility Theorem** states that **reliable consensus** is **impossible** in a distributed system with:  

1. **Asynchronous communication** (messages may be delayed).  
2. **Fault tolerance** (even one node may crash).  

**Why?**  
If a message is delayed, nodes can’t tell if it’s just late or if the sender has failed. This uncertainty prevents a guaranteed decision in finite time.  

**Key Point:**  
Perfect consensus can’t be guaranteed in such systems, but practical solutions like **Paxos** and **Raft** work well enough for most real-world scenarios.

## The Paxos Algorithm

**Paxos** is a consensus algorithm for distributed systems that ensures **agreement on a single value** even with **faulty nodes**.  

**Key Features:**  
- Handles **asynchronous communication** and **node failures**.  
- Guarantees **safety** (no conflicting decisions) but not **liveness** (progress may stall).  
- Uses a **proposer-acceptor-learner** model:  
  1. **Proposer** suggests a value.  
  2. **Acceptors** vote on proposals.  
  3. **Learners** finalize the agreed value.  

**Paxos** is reliable but **complex**, leading to simpler alternatives like **Raft** for practical use.

## The Raft Algorithm

**Raft** is a **consensus algorithm** designed to be **simpler and easier to understand** than Paxos, while achieving the same goals—**fault tolerance** and **consistency** in distributed systems.  

### **Key Features:**  
1. **Leader-based approach** – A **leader** is elected to manage log replication.  
2. **Log replication** – The leader ensures all nodes (followers) have the same log entries.  
3. **Safety** – Guarantees no conflicting logs, even during failures.  
4. **Simplicity** – Easier to implement and reason about compared to Paxos.  

Raft is widely used in real-world systems due to its **clarity and practicality**.

Steps:
1. Nodes start as followers.
2. Leader sends periodic heartbeats.
3. Followers reset election timeout on receiving a heartbeat.
4. Followers initiate new elections if no heartbeat is received.
5. The first candidate with a majority of votes becomes the leader.
6. The leader updates its log if a follower’s log is more up-to-date.
7. The leader appends client requests to its log.
8. Committed entries are applied to the state machine.
9. Nodes can be added or removed without disruption.
10. Raft allows dynamic changes to the cluster membership.


## Systems and consensus algorithms

| **System**              | **Consensus Algorithm**           | **Description**                                                                 |
|-------------------------|-----------------------------------|---------------------------------------------------------------------------------|
| **Etcd**                | Raft                              | Key-value store for configuration management and service discovery.             |
| **Apache Kafka**        | Zab (Zookeeper Atomic Broadcast)  | Event streaming platform using Zab for leader election and log replication.      |
| **Consul**              | Raft                              | Service discovery and configuration system using Raft for consistency.          |
| **ZooKeeper**           | Zab (Zookeeper Atomic Broadcast)  | Distributed coordination service for synchronization and configuration.          |
| **Google Spanner**      | Paxos                             | Globally distributed relational database ensuring consistency and availability.  |
| **CockroachDB**         | Raft                              | Distributed SQL database with Raft for replication and transactional guarantees. |
| **Tendermint**          | Tendermint (BFT Consensus)        | Blockchain consensus engine using Byzantine Fault Tolerance (BFT).               |
| **Ethereum 2.0**        | Casper (PoS)                      | Proof of Stake consensus for achieving scalability and energy efficiency.        |
| **Raiden Network**      | Ethereum PoW/PoS                  | Layer 2 payment network for Ethereum relying on Ethereum's consensus mechanism.  |
| **Hyperledger Fabric**  | Kafka (or Raft in newer versions) | Permissioned blockchain using Kafka or Raft for ordering and consensus.         |
| **Hazelcast**           | Raft                              | In-memory data grid using Raft for distributed consensus and coordination.       |
| **Istio**               | Paxos (via Consul or etcd)        | Service mesh using Paxos through integrated systems like Consul or etcd for service discovery and configuration. |
| **Kubernetes (K8s)**    | Raft                              | Container orchestration platform using Raft for maintaining consistency in etcd for cluster state and configuration. |

## Time

There is only a single node in a centralized system and, thus, only a single clock. This means we can maintain the illusion of a single, universal time dimension, which can then determine the order of the various events in the single node of the system.

On the other hand, in a distributed system, each node has its own clock. Each one of those clocks may run at a different rate or granularity, which means they will drift apart from each other. Consequently, in a distributed system, “there is no global clock, which could have been used to order events happening on different nodes of the system”.

**Logical clocks** are the alternative category of clocks that do not rely on physical processes to keep track of time. Instead, they make use of messages exchanged between the nodes of the system. This is also the main mechanism of information flow in a distributed system,

## Order

Determining the order of events is a common problem that needs to be solved in software systems.

However, there are two different possible types of ordering: **total** ordering and **partial** ordering.

In a distributed system it’s not that straightforward to impose a total order on events. This is because there are multiple nodes in the system, and events might be happening concurrently on different nodes. As a result, a distributed system can use any valid partial ordering of the events occurring if there is no strict need for a total ordering.

In distributed systems:  
- **Total Ordering** ensures all events are observed in the same order by every process, preserving a global sequence of events.  
- **Partial Ordering** guarantees only causally related events are observed in order, allowing concurrent events to occur independently without a fixed sequence.  

**Key Difference**: Total ordering enforces a strict global order, while partial ordering respects causality without imposing a global sequence. Example of causality: reply. to a comment.

Logical clock protocols:

| **Aspect**               | **Lamport Clocks**                           | **Vector Clocks**                              | **Version Vectors**                            | **Dotted Version Vectors**                     |
|--------------------------|----------------------------------------------|------------------------------------------------|------------------------------------------------|------------------------------------------------|
| **Purpose**              | Ensure **causal ordering** of events.        | Track **causal relationships** between events. | Manage **version histories** in replicated data. | Track **causal order** with precise conflict resolution. |
| **Structure**            | Single integer per process.                  | Array of integers, one per process.            | Map of process IDs to version counters.         | Pair of vector clock and **event identifier**. |
| **Causality Tracking**   | Partial ordering (causality preserved).      | Captures causality more precisely than Lamport. | Tracks causality using version numbers.         | Tracks causality and **unique event IDs**.     |
| **Concurrency Detection**| Cannot detect concurrency.                   | Detects concurrent events.                      | Detects concurrent versions.                    | Detects concurrent events and conflicts.       |
| **Complexity**           | **O(1)** per event.                          | **O(N)** per event (N = number of processes).   | **O(N)** per event.                              | **O(N)** per event.                             |
| **Usage**                | Ordering events in distributed systems.      | Tracking causality in distributed systems.      | Versioning in distributed databases.            | Precise version control with causality.        |

## Distributed Snapshot Problem

The **Distributed Snapshot Problem** addresses how to capture a consistent global state of a distributed system, where processes operate concurrently and communicate via messages. Since there is no global clock, processes cannot instantaneously record their states.  

Chandy-Lamport's **snapshot algorithm** solves this by:  
1. Initiating snapshots when a process records its state and sends markers to others.  
2. Recording incoming messages until markers are received.  
3. Ensuring each process eventually records its state and messages, yielding a consistent global snapshot.  

This helps in applications like checkpointing, debugging, and failure recovery.