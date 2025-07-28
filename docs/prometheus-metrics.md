# Axelar Prometheus Metrics Documentation

## Overview

The Axelar node exposes comprehensive metrics via a Prometheus endpoint at `/metrics` (default port 26660). These metrics provide deep insights into blockchain health, network performance, system resources, and Axelar-specific operations.

## Accessing Metrics

### Local Access
```bash
# Port forward to access metrics
kubectl port-forward svc/axelar-node-service 26660:26660 -n axelar-testnet

# View metrics
curl http://localhost:26660/metrics
```

### Production Access
```bash
# Direct service access within cluster
curl http://axelar-node-service.axelar-mainnet.svc.cluster.local:26660/metrics
```

## Metric Categories

### 1. 🔗 Blockchain Consensus Metrics

#### `tendermint_consensus_height` (gauge)
- **Description**: Current block height of the chain
- **Use Case**: Monitor blockchain sync status and block production
- **Sample Value**: `12411`
- **Alerts**:
  - ⚠️ Warning: Height not increasing for >5 minutes
  - 🚨 Critical: Height not increasing for >15 minutes

#### `tendermint_consensus_validators` (gauge)
- **Description**: Total number of validators in the network
- **Use Case**: Monitor validator set size
- **Sample Value**: `75`
- **Normal Range**: 50-150 for most networks

#### `tendermint_consensus_validator_power` (gauge)
- **Description**: Voting power of this validator (0 for non-validators)
- **Use Case**: Confirm validator status and voting weight
- **Sample Value**: `0` (non-validator node)
- **Alerts**: Monitor for unexpected power changes

#### `tendermint_consensus_validator_last_signed_height` (gauge)
- **Description**: Last block height this validator signed
- **Use Case**: Monitor validator participation
- **Sample Value**: `12410`
- **Alerts**: 🚨 Critical if behind current height by >10 blocks

#### `tendermint_consensus_validator_missed_blocks` (counter)
- **Description**: Total number of blocks missed by this validator
- **Use Case**: Track validator performance and slashing risk
- **Sample Value**: `0`
- **Alerts**: 🚨 Critical if >50 (approaching slashing threshold)

#### `tendermint_consensus_block_interval_seconds` (histogram)
- **Description**: Distribution of time between blocks
- **Use Case**: Monitor block production consistency
- **Buckets**: 1s, 2s, 5s, 10s, +Inf
- **Alerts**: ⚠️ Warning if average >10s

#### `tendermint_mempool_size` (gauge)
- **Description**: Number of transactions in mempool
- **Use Case**: Monitor network congestion
- **Sample Value**: `41`
- **Alerts**: ⚠️ Warning if >1000, 🚨 Critical if >5000

### 2. 🌐 Network & P2P Metrics

#### `tendermint_p2p_peers` (gauge)
- **Description**: Number of connected peers
- **Use Case**: Monitor network connectivity health
- **Sample Value**: `12`
- **Alerts**:
  - 🚨 Critical: <3 peers (network isolation)
  - ⚠️ Warning: <8 peers (poor connectivity)
  - ✅ Healthy: 8-50 peers

#### `tendermint_p2p_peer_receive_bytes_total` (counter)
- **Description**: Total bytes received from peers
- **Use Case**: Monitor network throughput and data sync
- **Sample Value**: `6,238,272` bytes (5.95 MB)
- **Monitoring**: Track rate of increase for bandwidth usage

#### `tendermint_p2p_peer_send_bytes_total` (counter)
- **Description**: Total bytes sent to peers
- **Use Case**: Monitor outbound network activity
- **Sample Value**: `3,777,339` bytes (3.60 MB)
- **Monitoring**: Compare with receive rate for network balance

### 3. 💻 System Performance Metrics

#### `process_resident_memory_bytes` (gauge)
- **Description**: Resident memory size in bytes
- **Use Case**: Monitor memory consumption and detect leaks
- **Sample Value**: `3,059,358,021` bytes (2.85 GB)
- **Alerts**:
  - ⚠️ Warning: >8 GB (potential memory leak)
  - 🚨 Critical: >12 GB (system instability risk)

#### `process_cpu_seconds_total` (counter)
- **Description**: Total CPU time consumed
- **Use Case**: Monitor CPU usage trends
- **Sample Value**: `315147367.16` seconds
- **Monitoring**: Calculate rate for current CPU usage percentage

### 4. 🔧 Go Runtime Metrics

#### `go_memstats_alloc_bytes` (gauge)
- **Description**: Bytes allocated and still in use
- **Use Case**: Monitor Go memory allocation patterns
- **Sample Value**: `101,287,742` bytes (96.5 MB)
- **Monitoring**: Track for memory allocation efficiency

#### `go_goroutines` (gauge)
- **Description**: Number of goroutines currently running
- **Use Case**: Monitor concurrency and detect goroutine leaks
- **Sample Value**: `160`
- **Alerts**: ⚠️ Warning if >1000 (potential goroutine leak)

### 5. ⚡ Axelar-Specific Metrics

#### `axelar_vote_events_total` (counter)
- **Description**: Total number of vote events processed
- **Use Case**: Monitor cross-chain voting activity
- **Sample Value**: `1234`
- **Alerts**: ⚠️ Warning if not increasing (validator participation issues)

#### `axelar_heartbeat_events_total` (counter)
- **Description**: Total number of heartbeat events
- **Use Case**: Monitor validator liveness and network participation
- **Sample Value**: `5678`
- **Monitoring**: Should increase regularly for active validators

#### `axelar_key_assignments_total` (counter)
- **Description**: Total number of key assignments
- **Use Case**: Monitor key management operations
- **Sample Value**: `42`
- **Monitoring**: Track for key rotation and security events

#### `axelar_sign_attempts_total` (counter)
- **Description**: Total number of signing attempts
- **Use Case**: Monitor cross-chain transaction signing activity
- **Sample Value**: `987`
- **Monitoring**: Compare with successful signs for error rates

## Prometheus Query Examples

### Basic Health Checks

```promql
# Block production rate (blocks per minute)
rate(tendermint_consensus_height[5m]) * 60

# Memory usage in GB
process_resident_memory_bytes / 1024^3

# Network throughput (bytes per second)
rate(tendermint_p2p_peer_receive_bytes_total[1m])

# Peer connectivity status
tendermint_p2p_peers > 5
```

### Advanced Monitoring

```promql
# Validator uptime (blocks behind)
tendermint_consensus_height - tendermint_consensus_validator_last_signed_height

# Mempool congestion level
tendermint_mempool_size / 1000

# Cross-chain activity rate
rate(axelar_vote_events_total[10m])

# System resource utilization
(process_resident_memory_bytes / 1024^3) / 16  # Assuming 16GB limit
```

### Alerting Rules

```yaml
# Prometheus alerting rules
groups:
- name: axelar_node_alerts
  rules:
  - alert: AxelarNodeDown
    expr: up{job="axelar-node"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Axelar node is down"

  - alert: AxelarBlockHeightStalled
    expr: increase(tendermint_consensus_height[5m]) == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Block height not increasing"

  - alert: AxelarLowPeerCount
    expr: tendermint_p2p_peers < 3
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "Low peer count: {{ $value }}"

  - alert: AxelarHighMemoryUsage
    expr: process_resident_memory_bytes / 1024^3 > 8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High memory usage: {{ $value }}GB"

  - alert: AxelarValidatorMissedBlocks
    expr: tendermint_consensus_validator_missed_blocks > 10
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Validator missed {{ $value }} blocks"
```

## Grafana Dashboard Integration

### Key Panels to Create

1. **Blockchain Health**
   - Block height over time
   - Block production rate
   - Validator power and status

2. **Network Connectivity**
   - Peer count
   - Network throughput (in/out)
   - Connection stability

3. **System Resources**
   - Memory usage
   - CPU utilization
   - Go runtime metrics

4. **Axelar Operations**
   - Vote events rate
   - Heartbeat frequency
   - Key management activity

### Sample Grafana Queries

```json
{
  "targets": [
    {
      "expr": "tendermint_consensus_height",
      "legendFormat": "Block Height"
    },
    {
      "expr": "tendermint_p2p_peers",
      "legendFormat": "Connected Peers"
    },
    {
      "expr": "process_resident_memory_bytes / 1024^3",
      "legendFormat": "Memory Usage (GB)"
    }
  ]
}
```

## Metric Collection Best Practices

### Scraping Configuration

```yaml
# Prometheus scrape config
scrape_configs:
- job_name: 'axelar-nodes'
  static_configs:
  - targets: ['axelar-node-service:26660']
  scrape_interval: 15s
  metrics_path: /metrics
  scrape_timeout: 10s
```

### Retention and Storage

- **High-frequency metrics**: Store for 7-30 days
- **Aggregated metrics**: Store for 1-2 years
- **Critical alerts**: Store indefinitely

### Performance Considerations

- Scrape interval: 15-30 seconds for production
- Timeout: 10 seconds maximum
- Cardinality: Monitor metric cardinality growth
- Storage: Plan for ~1KB per scrape per target

## Troubleshooting Common Issues

### Metrics Not Available
```bash
# Check if metrics endpoint is accessible
curl -I http://localhost:26660/metrics

# Verify Prometheus annotations
kubectl describe pod <pod-name> | grep prometheus
```

### High Cardinality
```bash
# Check metric cardinality
curl -s http://localhost:26660/metrics | grep -c "^[^#]"
```

### Missing Metrics
```bash
# Verify all expected metrics are present
curl -s http://localhost:26660/metrics | grep -E "(tendermint_|axelar_)" | wc -l
```

## Security Considerations

- **Network Access**: Restrict metrics endpoint to monitoring systems only
- **Authentication**: Consider adding authentication for production
- **Sensitive Data**: Ensure no sensitive information is exposed in metric labels
- **Rate Limiting**: Implement rate limiting to prevent abuse

## Conclusion

The Axelar Prometheus metrics provide comprehensive observability into:
- ✅ Blockchain synchronization and consensus
- ✅ Network connectivity and performance
- ✅ System resource utilization
- ✅ Axelar-specific cross-chain operations
- ✅ Validator performance and participation

These metrics enable proactive monitoring, alerting, and troubleshooting of Axelar nodes in production environments.
