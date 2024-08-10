# Designing systems that scale

## Scaling

**Horizontal** scaling - every server should be "stateless" and assume that any request can been handled by itself or by any other server.


## CAP theorem

The CAP theorem, also known as Brewer's theorem, is a fundamental principle in distributed computing. It states that distributed data store can provide only two of the following three guarantees simultaneously:

1. Consistency (C): Do I get back what I just wrote right away? An Eventually Consistent database means that it takes time to for changes to be written throughout the system, and the data that you've written might not be read back immediately.
2. Availability (A): Do I have any single points of failure that can go down?
3. Partition Tolerance (P): Can I horizontally scale the system easily?

```
               Consistency (C)
                  /\
                 /  \
                /    \
               /      \
              /        \
             /          \
            /            \
           /              \
Availability (A)----------Partition Tolerance (P)
```

The trade offs are not as strong as they used to be, practically speaking you get all 3 with modern databases. But the tradeoffs still exist.

Examples:
- MongoDB: Strong C and P, but trading A.
- Casandra: Strong A and P, giving up C. There is no single master in Casandra. That means we have to replicate data across all of the nodes as we go, and because of that it is eventually consistent.

Be sure to understand requirements about scaling, consistency and availability before proposing a specific database solution.

## Caching

Hitting disk is expensive. Where possible it is better to store data in memory.

- It can be beneficial to have a dedicate fleet of cache servers, sitting along application servers.
- You can also build caching into your applications.
- With distributed caching, every cache server is responsible for some subset of data in the database underneath it. The hash function allows us to quickly map which server do I talk to.
- It is very appropriate for the applications that have more reads than writes. Whenever I write information it will invalidate cache somewhere. So, if I do a lot of writes this is not very efficient.
- The *expiration policy* dictates how long cache is valid for. Too long and your data may go stale. Too short and the cache won't do that good.
- *Hostspots* can be a problem when certain information is more popular (the 'celebrity' problem, example with Brad Pitt in imdb). Intelligent caching solutions can redistribute (e.g. have a host just for Brad Pitt).
- *Cold-start* is also a problem. How do you initially warm up the cache without bringing down whatever you are caching. E.g. while the cache is warming up the traffic will go directly to the database. If the traffic is large then the database might fail.

## Eviction policies

There are at least 3 ways:
- LRU: Least Recently Used.
  Use a linked list where I am moving most recently accessed thing to the front, and the least frequently accessed thing to the end; and have a head pointer and a tail pointer that allows me to quickly reference is the head of the tail of that list. So, if I need to evict something, I check where the tail pointer is, dispose of that thing, get rid of its memory and move the tail to what is before. If I access something, I move that think to the front and put the head pointer on it.
- LFU: Least Frequently Used
- FIFO: First In First Out

## Content Delivery Networks (CDNs)

- Geographically distributed servers (to reduce latency)
- Good for local hosting of HTML, CSS, JS, images
- Some limited computation may be available as well
- CDNs are expensive. Sometimes need to make a tradeoff what goes into a CDN and what does not

CDN providers
- AWS/Google/Azure CDN
- Akamai 
- CloudFare