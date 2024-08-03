# Designing systems that scale

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