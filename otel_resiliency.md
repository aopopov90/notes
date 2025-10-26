1. Receivers
gRPC - max_connection_idle
Tweak other properties

2. Processors
2 examples:
- `Memory Limiter`: The memory limiter processor is used to prevent out of memory situations on the collector, performing periodic checks of memory usage and starting to refuse data and forcing GC to reduce memory consumption when defined limits have been exceeded.
- `Batch processor`: The batch processor helps better compress the data and reduce the number of outgoing connections required to transmit the data, and should be defined in the pipeline after the memory_limiter as well as any sampling processors.

3. Exporters
- `Persistent Queue`: If the collector instance is killed while having some items in the persistent queue (on disk), on restart the items will be picked and the exporting is continued.
- `Queue Size`: Maximum number of batches kept in memory before dropping; User should calculate this as:
`seconds * batches to survive`

4. Connection tweaks
- `configgrpc`: tweaks for better client-side load-balancing
- `confighttp` tweaks for better batching

5. How to detect failures on OTEL collector
Metrics:
- `otelcol_exporter_sent_log_records`
- `otelcol_receiver_refused_log_records`
- `otelcol_exporter_queue_size`
- `otelcol_exporter_queue_capacity`

6. 
Telemetrygen - used to generate fake telemetry traffic
OpenTelemetryOperator CRD

7. Future improvements
Memory limiter as extension
Batching as exporter-specific feature
• Better self-observability
Component-specific resiliency (routing, load-balancer,...)


https://youtu.be/S1K26-2wG8w?si=Bdx0JIgSCano63mw