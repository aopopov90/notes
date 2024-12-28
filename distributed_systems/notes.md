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

