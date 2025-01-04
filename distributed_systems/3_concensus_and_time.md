# Consensus and Time in Distributed Systems

## Defining the Consensus Problem

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

