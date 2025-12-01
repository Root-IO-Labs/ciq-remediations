# CVE-2025-8677 Proof-of-Concept Tests

This directory contains proof-of-concept tests to demonstrate the CVE-2025-8677 vulnerability and validate the security patch effectiveness.

## Overview

CVE-2025-8677 is a CPU exhaustion vulnerability in BIND 9.11.4-P2's DNSSEC validator. Attackers can craft malformed DNSKEY records that:
- Pass initial format validation
- Match algorithm and key ID filters
- Fail during cryptographic validation
- Cause the validator to continue processing in expensive loops

This leads to CPU exhaustion and potential denial of service.

## Quick Start

```bash
cd ../../docker

# Run complete POC test (build + test + report)
./run-poc-test.sh all

# View results
cat ../results/comparison_report.md
```

## Test Components

### 1. Malformed DNSKEY Generator

**File**: `generate_malformed_dnskey.py`

Generates various types of malformed DNSKEY records:
- Invalid RSA exponent length
- Truncated RSA modulus
- Invalid ECDSA curve points
- Zero-length public keys
- Corrupted RSA exponents

**Usage**:
```bash
python3 generate_malformed_dnskey.py
```

**Output**:
- `malformed.zone` - Zone file with malformed records
- `query_malformed.sh` - Query script

### 2. BIND Configuration

**Files**:
- `named.conf` - BIND server configuration
- `root.hint` - Root DNS hints
- `malformed.zone` - Zone with malformed DNSKEY records

### 3. Comparison Test Script

**File**: `compare_patched_unpatched.sh`

Comprehensive test that:
- Queries both unpatched and patched servers
- Measures response times
- Monitors CPU usage
- Detects timeouts
- Generates detailed comparison report

### 4. Docker Environment

**Files** (in `docker/`):
- `docker-compose.poc.yml` - POC test orchestration
- `Dockerfile.bind-server` - BIND server container
- `Dockerfile.poc-client` - Test client container
- `run-poc-test.sh` - Main orchestration script

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  POC Client     │────▶│  Unpatched      │     │   Patched       │
│  (172.25.0.x)   │     │  BIND Server    │     │   BIND Server   │
│                 │     │  (172.25.0.10)  │     │  (172.25.0.20)  │
│ - dig queries   │────▶│  Port 5301      │     │   Port 5302     │
│ - CPU monitor   │     │                 │     │                 │
│ - Comparison    │     │  Vulnerable to  │     │   Protected     │
│   reporter      │     │  CVE-2025-8677  │     │   by patch      │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         │                       ▼                       ▼
         └──────────────▶  CPU Exhaustion        Fast Failure
                          Long Response           <1s Response
                          >30s or Timeout         SERVFAIL
```

## Running Tests

### Complete Test

```bash
cd ../../docker
./run-poc-test.sh all
```

This will:
1. Build unpatched BIND container from `workspace/workdir/target`
2. Build patched BIND container from `workspace/workdir/target_draft`
3. Build POC test client
4. Start both BIND servers
5. Run comparison tests
6. Generate detailed report

### Build Only

```bash
./run-poc-test.sh build
```

### Test Only (Requires Pre-built Containers)

```bash
./run-poc-test.sh test
```

### View Server Logs

```bash
./run-poc-test.sh logs
```

### Interactive Debugging

```bash
./run-poc-test.sh shell

# Inside container:
dig @172.25.0.10 example.com DNSKEY +dnssec  # Query unpatched
dig @172.25.0.20 example.com DNSKEY +dnssec  # Query patched
```

### Cleanup

```bash
./run-poc-test.sh clean
```

## Expected Results

### Unpatched BIND Behavior

```
❌ CPU Exhaustion Demonstrated:
- High response times (>10s average)
- Multiple timeout queries (>30s)
- Server struggles with validation
- CPU usage spikes during queries
- Expensive validation loops observed
```

### Patched BIND Behavior

```
✅ Vulnerability Mitigated:
- Fast response times (<1s average)
- No timeout queries
- Early error termination
- Low CPU usage
- Fail-fast on malformed keys
```

## Test Output

### Generated Files

All files are saved to `../../results/`:

**Unpatched Server**:
- `unpatched_results.txt` - Detailed query results
- `unpatched_timing.csv` - Timing data (CSV format)
- `unpatched_cpu.log` - CPU usage log

**Patched Server**:
- `patched_results.txt` - Detailed query results
- `patched_timing.csv` - Timing data (CSV format)
- `patched_cpu.log` - CPU usage log

**Comparison**:
- `comparison_report.md` - Executive summary with analysis

### Sample Comparison Report

```markdown
# CVE-2025-8677 POC Comparison Report

## Test Results

### Unpatched BIND
- Successful Queries: 3 / 10
- Failed Queries: 0
- Timeout Queries: 7
- Average Response Time: 28.5s

### Patched BIND
- Successful Queries: 10 / 10
- Failed Queries: 0
- Timeout Queries: 0
- Average Response Time: 0.3s

## Analysis
✅ CVE-2025-8677 CONFIRMED in Unpatched Version
✅ Patch Effectiveness CONFIRMED (98.9% improvement)
```

## Troubleshooting

### Servers Not Starting

```bash
# Check logs
docker-compose -f docker/docker-compose.poc.yml logs

# Verify zone file
cat tests/poc/malformed.zone

# Check configuration
docker-compose -f docker/docker-compose.poc.yml exec bind-unpatched /usr/local/bind/sbin/named-checkconf /etc/named.conf
```

### No Timeout Observed

This can happen if:
- DNSSEC validation is disabled
- Zone file not loaded correctly
- Network issues preventing queries

**Solutions**:
1. Verify DNSSEC is enabled in `named.conf`
2. Check zone file is mounted correctly
3. Ensure malformed keys are properly formatted
4. Increase number of queries in test script

### Container Build Failures

```bash
# Clean and rebuild
docker-compose -f docker/docker-compose.poc.yml down -v
docker system prune -f
./run-poc-test.sh build
```

## Security Considerations

⚠️ **Important Notes**:

1. This POC is for **authorized testing only**
2. Only run against your own systems
3. POC demonstrates denial-of-service conditions
4. Resource exhaustion is intentional
5. Not for use in production environments

## Technical Details

### Vulnerability Mechanics

**Unpatched Code Path**:
```c
// In get_dst_key():
if (result != ISC_R_SUCCESS) {
    // Original: Sets DNS_R_CONTINUE and continues loop
    result = DNS_R_CONTINUE;  // Keeps processing!
}

// In isselfsigned():
if (result != ISC_R_SUCCESS)
    continue;  // Keeps processing invalid keys!
```

**Patched Code Path**:
```c
// In get_dst_key():
if (result == ISC_R_NOTFOUND) {
    result = DNS_R_CONTINUE;  // Expected case
} else if (result != ISC_R_SUCCESS) {
    return (result);  // Fail fast!
}

// In isselfsigned():
if (result != ISC_R_SUCCESS) {
    return (result);  // Fail fast!
}
```

### Test Methodology

1. **Zone Loading**: Malformed DNSKEY records loaded into BIND
2. **Query Execution**: DNSSEC-enabled queries for DNSKEY type
3. **Validation Trigger**: BIND attempts to validate malformed keys
4. **Loop Detection**: Unpatched version continues validation
5. **Measurement**: Response time and CPU usage measured
6. **Comparison**: Patched vs unpatched behavior analyzed

## References

- **CVE**: CVE-2025-8677
- **CVSS Score**: 7.5 HIGH
- **CWE**: CWE-400 (Resource Exhaustion)
- **Affected**: BIND 9.11.4-P2
- **Fixed**: Security patch applied to `workspace/workdir/target_draft`

## Contributing

To improve the POC tests:
1. Add additional malformed key types
2. Improve CPU/memory monitoring
3. Add automated analysis tools
4. Enhance reporting format
5. Add regression tests

## Support

For issues with the POC:
1. Check this README
2. Review Docker logs
3. Verify zone file syntax
4. Check BIND configuration
5. Review generated reports

---

**Last Updated**: 2025-11-27
**Maintainer**: Security Testing Team
**Environment**: Docker on CentOS 7.9
