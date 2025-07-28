#!/usr/bin/env python3
"""
Mock Axelar node that serves Prometheus metrics for ARM64 testing
This simulates the key metrics that would be available from a real Axelar node
"""

import http.server
import socketserver
import time
import random
from urllib.parse import urlparse

class MockAxelarHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        parsed_path = urlparse(self.path)
        
        if parsed_path.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            health_response = '{"status": "ok", "height": "12345", "catching_up": false}'
            self.wfile.write(health_response.encode())
            
        elif parsed_path.path == '/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            status_response = '''
            {
                "jsonrpc": "2.0",
                "id": "",
                "result": {
                    "node_info": {
                        "protocol_version": {"p2p": "8", "block": "11", "app": "0"},
                        "id": "mock-node-id",
                        "listen_addr": "tcp://0.0.0.0:26656",
                        "network": "axelar-testnet-lisbon-3",
                        "version": "v0.35.5",
                        "channels": "40202122233038606100",
                        "moniker": "mock-axelar-node",
                        "other": {"tx_index": "on", "rpc_address": "tcp://0.0.0.0:26657"}
                    },
                    "sync_info": {
                        "latest_block_hash": "mock-hash",
                        "latest_app_hash": "mock-app-hash",
                        "latest_block_height": "12345",
                        "latest_block_time": "2025-01-28T09:00:00.000Z",
                        "earliest_block_hash": "mock-early-hash",
                        "earliest_app_hash": "mock-early-app-hash",
                        "earliest_block_height": "1",
                        "earliest_block_time": "2024-01-01T00:00:00.000Z",
                        "catching_up": false
                    },
                    "validator_info": {
                        "address": "mock-validator-address",
                        "pub_key": {"type": "tendermint/PubKeyEd25519", "value": "mock-pubkey"},
                        "voting_power": "0"
                    }
                }
            }
            '''
            self.wfile.write(status_response.encode())
            
        elif parsed_path.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            
            # Generate mock Prometheus metrics similar to what Axelar would provide
            current_time = int(time.time())
            block_height = 12345 + int(time.time()) % 100  # Simulate increasing block height
            peer_count = random.randint(8, 15)
            memory_usage = random.randint(2000000000, 4000000000)  # 2-4GB in bytes
            cpu_usage = random.uniform(0.1, 0.8)
            
            metrics = f'''# HELP tendermint_consensus_height Height of the chain
# TYPE tendermint_consensus_height gauge
tendermint_consensus_height {block_height}

# HELP tendermint_p2p_peers Number of peers
# TYPE tendermint_p2p_peers gauge
tendermint_p2p_peers {peer_count}

# HELP tendermint_consensus_validators Number of validators
# TYPE tendermint_consensus_validators gauge
tendermint_consensus_validators 75

# HELP tendermint_consensus_validator_power Voting power of the validator
# TYPE tendermint_consensus_validator_power gauge
tendermint_consensus_validator_power 0

# HELP tendermint_consensus_validator_last_signed_height Last height signed by validator
# TYPE tendermint_consensus_validator_last_signed_height gauge
tendermint_consensus_validator_last_signed_height {block_height - 1}

# HELP tendermint_consensus_validator_missed_blocks Number of missed blocks
# TYPE tendermint_consensus_validator_missed_blocks counter
tendermint_consensus_validator_missed_blocks 0

# HELP tendermint_consensus_block_interval_seconds Time between blocks
# TYPE tendermint_consensus_block_interval_seconds histogram
tendermint_consensus_block_interval_seconds_bucket{{le="1"}} 0
tendermint_consensus_block_interval_seconds_bucket{{le="2"}} 45
tendermint_consensus_block_interval_seconds_bucket{{le="5"}} 120
tendermint_consensus_block_interval_seconds_bucket{{le="10"}} 150
tendermint_consensus_block_interval_seconds_bucket{{le="+Inf"}} 150
tendermint_consensus_block_interval_seconds_sum 450.5
tendermint_consensus_block_interval_seconds_count 150

# HELP tendermint_mempool_size Number of transactions in mempool
# TYPE tendermint_mempool_size gauge
tendermint_mempool_size {random.randint(0, 50)}

# HELP tendermint_p2p_peer_receive_bytes_total Bytes received from peers
# TYPE tendermint_p2p_peer_receive_bytes_total counter
tendermint_p2p_peer_receive_bytes_total {random.randint(1000000, 10000000)}

# HELP tendermint_p2p_peer_send_bytes_total Bytes sent to peers
# TYPE tendermint_p2p_peer_send_bytes_total counter
tendermint_p2p_peer_send_bytes_total {random.randint(1000000, 10000000)}

# HELP process_resident_memory_bytes Resident memory size in bytes
# TYPE process_resident_memory_bytes gauge
process_resident_memory_bytes {memory_usage}

# HELP process_cpu_seconds_total Total user and system CPU time spent in seconds
# TYPE process_cpu_seconds_total counter
process_cpu_seconds_total {cpu_usage * current_time}

# HELP go_memstats_alloc_bytes Number of bytes allocated and still in use
# TYPE go_memstats_alloc_bytes gauge
go_memstats_alloc_bytes {random.randint(50000000, 200000000)}

# HELP go_goroutines Number of goroutines that currently exist
# TYPE go_goroutines gauge
go_goroutines {random.randint(100, 500)}

# HELP axelar_vote_events_total Total number of vote events
# TYPE axelar_vote_events_total counter
axelar_vote_events_total 1234

# HELP axelar_heartbeat_events_total Total number of heartbeat events
# TYPE axelar_heartbeat_events_total counter
axelar_heartbeat_events_total 5678

# HELP axelar_key_assignments_total Total number of key assignments
# TYPE axelar_key_assignments_total counter
axelar_key_assignments_total 42

# HELP axelar_sign_attempts_total Total number of sign attempts
# TYPE axelar_sign_attempts_total counter
axelar_sign_attempts_total 987
'''
            self.wfile.write(metrics.encode())
            
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

    def log_message(self, format, *args):
        print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {format % args}")

if __name__ == "__main__":
    PORT = 26660
    print(f"Starting Mock Axelar Node with Prometheus metrics on port {PORT}")
    print(f"Endpoints:")
    print(f"  Health: http://localhost:{PORT}/health")
    print(f"  Status: http://localhost:{PORT}/status") 
    print(f"  Metrics: http://localhost:{PORT}/metrics")
    
    with socketserver.TCPServer(("", PORT), MockAxelarHandler) as httpd:
        print(f"Mock Axelar node serving at port {PORT}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down mock Axelar node...")
            httpd.shutdown()
