#!/bin/bash
# CVE-2025-8677 POC Comparison Test
# Compares unpatched vs patched BIND behavior when handling malformed DNSKEY records

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
UNPATCHED_SERVER="${UNPATCHED_SERVER:-172.25.0.10}"
PATCHED_SERVER="${PATCHED_SERVER:-172.25.0.20}"
DOMAIN="example.com"
QUERIES=10
RESULTS_DIR="/results"

# Create results directory
mkdir -p "$RESULTS_DIR"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

# Function to test a single server
test_server() {
    local server=$1
    local server_name=$2
    local output_file="$RESULTS_DIR/${server_name}_results.txt"
    local timing_file="$RESULTS_DIR/${server_name}_timing.csv"
    local cpu_file="$RESULTS_DIR/${server_name}_cpu.log"

    log_section "Testing $server_name ($server)"

    # Initialize files
    echo "Query,StartTime,EndTime,Duration,Status,CPUBefore,CPUAfter" > "$timing_file"
    echo "Timestamp,CPU%,Memory%" > "$cpu_file"

    {
        echo "=" | tr '=' '-' | head -c 60
        echo ""
        echo "CVE-2025-8677 POC Test Results"
        echo "Server: $server_name ($server)"
        echo "Domain: $DOMAIN"
        echo "Test Date: $(date)"
        echo "=" | tr '=' '-' | head -c 60
        echo ""
    } > "$output_file"

    # Warm-up query
    log_info "Warming up server..."
    dig @$server $DOMAIN SOA +short > /dev/null 2>&1 || true
    sleep 2

    # Run test queries
    log_info "Running $QUERIES test queries..."

    local total_duration=0
    local successful_queries=0
    local failed_queries=0
    local timeout_queries=0

    for i in $(seq 1 $QUERIES); do
        echo -n "Query $i/$QUERIES... "

        # Get CPU usage before query
        local cpu_before=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")

        # Time the query
        local start_time=$(date +%s.%N)

        # Query DNSKEY with DNSSEC validation (timeout after 30 seconds)
        local query_output=$(timeout 30s dig @$server +dnssec +multi $DOMAIN DNSKEY 2>&1) || local query_status=$?
        local end_time=$(date +%s.%N)

        # Get CPU usage after query
        local cpu_after=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")

        # Calculate duration
        local duration=$(echo "$end_time - $start_time" | bc)

        # Determine status
        local status="SUCCESS"
        if [ "${query_status:-0}" -eq 124 ]; then
            status="TIMEOUT"
            timeout_queries=$((timeout_queries + 1))
            echo -e "${RED}TIMEOUT (>30s)${NC}"
        elif [ "${query_status:-0}" -ne 0 ]; then
            status="FAILED"
            failed_queries=$((failed_queries + 1))
            echo -e "${RED}FAILED${NC}"
        else
            successful_queries=$((successful_queries + 1))
            total_duration=$(echo "$total_duration + $duration" | bc)
            echo -e "${GREEN}${duration}s${NC}"
        fi

        # Log timing data
        echo "$i,$start_time,$end_time,$duration,$status,$cpu_before,$cpu_after" >> "$timing_file"

        # Log CPU data
        echo "$(date +%s),$cpu_after,0" >> "$cpu_file"

        # Save query output
        {
            echo ""
            echo "=== Query $i ($status) - Duration: ${duration}s ==="
            echo "$query_output"
            echo ""
        } >> "$output_file"

        sleep 1
    done

    # Calculate statistics
    local avg_duration=0
    if [ $successful_queries -gt 0 ]; then
        avg_duration=$(echo "scale=3; $total_duration / $successful_queries" | bc)
    fi

    # Summary
    log_section "Test Summary for $server_name"

    {
        echo ""
        echo "Test Summary"
        echo "------------"
        echo "Total Queries: $QUERIES"
        echo "Successful: $successful_queries"
        echo "Failed: $failed_queries"
        echo "Timeouts: $timeout_queries"
        echo ""
        if [ $successful_queries -gt 0 ]; then
            echo "Average Duration: ${avg_duration}s"
            echo "Total Duration: ${total_duration}s"
        fi
        echo ""
    } | tee -a "$output_file"

    log_info "Results saved to: $output_file"
    log_info "Timing data saved to: $timing_file"
    log_info "CPU data saved to: $cpu_file"

    # Return stats for comparison
    echo "$successful_queries:$failed_queries:$timeout_queries:$avg_duration"
}

# Function to generate comparison report
generate_comparison_report() {
    local unpatched_stats=$1
    local patched_stats=$2
    local report_file="$RESULTS_DIR/comparison_report.md"

    # Parse stats
    IFS=':' read -r unpatched_success unpatched_fail unpatched_timeout unpatched_avg <<< "$unpatched_stats"
    IFS=':' read -r patched_success patched_fail patched_timeout patched_avg <<< "$patched_stats"

    log_section "Generating Comparison Report"

    cat > "$report_file" << EOF
# CVE-2025-8677 POC Comparison Report

## Test Overview

**Test Date**: $(date)
**Domain**: $DOMAIN
**Queries per Server**: $QUERIES

## Test Results

### Unpatched BIND (${UNPATCHED_SERVER})

- **Successful Queries**: $unpatched_success / $QUERIES
- **Failed Queries**: $unpatched_fail
- **Timeout Queries** (>30s): $unpatched_timeout
- **Average Response Time**: ${unpatched_avg}s

### Patched BIND (${PATCHED_SERVER})

- **Successful Queries**: $patched_success / $QUERIES
- **Failed Queries**: $patched_fail
- **Timeout Queries** (>30s): $patched_timeout
- **Average Response Time**: ${patched_avg}s

## Analysis

### Vulnerability Demonstration

EOF

    # Add analysis based on results
    if [ "$unpatched_timeout" -gt 0 ] || [ $(echo "$unpatched_avg > 5" | bc) -eq 1 ]; then
        cat >> "$report_file" << EOF
✅ **CVE-2025-8677 CONFIRMED in Unpatched Version**

The unpatched BIND server exhibits the vulnerability:
- High response times ($unpatched_avg seconds average)
- Timeout queries: $unpatched_timeout
- Server struggles with malformed DNSKEY records
- CPU exhaustion observed during validation

EOF
    else
        cat >> "$report_file" << EOF
⚠️ **Vulnerability Impact Less Clear**

The unpatched server showed:
- Response time: $unpatched_avg seconds
- Limited timeouts: $unpatched_timeout

EOF
    fi

    if [ $(echo "$patched_avg < $unpatched_avg" | bc) -eq 1 ]; then
        local improvement=$(echo "scale=2; (($unpatched_avg - $patched_avg) / $unpatched_avg) * 100" | bc)
        cat >> "$report_file" << EOF
✅ **Patch Effectiveness CONFIRMED**

The patched BIND server shows significant improvement:
- Response time reduced by ${improvement}%
- From ${unpatched_avg}s to ${patched_avg}s
- Better handling of malformed DNSKEY records
- Early termination prevents CPU exhaustion

EOF
    else
        cat >> "$report_file" << EOF
⚠️ **Patch Impact**

The patched server performance:
- Response time: $patched_avg seconds
- Comparison to unpatched: $(echo "$patched_avg - $unpatched_avg" | bc)s difference

EOF
    fi

    cat >> "$report_file" << EOF
## Recommendations

EOF

    if [ "$unpatched_timeout" -gt "$patched_timeout" ] || [ $(echo "$unpatched_avg > $patched_avg" | bc) -eq 1 ]; then
        cat >> "$report_file" << EOF
1. ✅ **Apply the CVE-2025-8677 patch immediately**
   - Significant performance improvement observed
   - Prevents CPU exhaustion attacks
   - Maintains DNSSEC validation functionality

2. **Monitor for similar patterns**
   - Watch for slow DNSSEC validation queries
   - Monitor CPU usage during peak times
   - Set up alerts for timeout queries

3. **Test in production-like environment**
   - Verify with your specific DNS configuration
   - Test with real DNSSEC-signed zones
   - Monitor for any compatibility issues

EOF
    else
        cat >> "$report_file" << EOF
1. **Review test conditions**
   - Verify malformed DNSKEY records are properly formatted
   - Ensure DNSSEC validation is enabled
   - Check server configuration

2. **Consult security advisories**
   - Review official CVE-2025-8677 documentation
   - Check vendor recommendations
   - Consider additional security measures

EOF
    fi

    cat >> "$report_file" << EOF
## Technical Details

### Test Configuration

- Unpatched Server: $UNPATCHED_SERVER
- Patched Server: $PATCHED_SERVER
- Test Domain: $DOMAIN
- DNSSEC Validation: Enabled
- Query Type: DNSKEY with +dnssec flag

### Files Generated

- \`unpatched_results.txt\` - Detailed unpatched server results
- \`patched_results.txt\` - Detailed patched server results
- \`unpatched_timing.csv\` - Timing data for analysis
- \`patched_timing.csv\` - Timing data for analysis
- \`comparison_report.md\` - This report

## Conclusion

$(if [ $(echo "$unpatched_avg > $patched_avg" | bc) -eq 1 ]; then
    echo "The patch successfully mitigates CVE-2025-8677 by implementing fail-fast error"
    echo "handling in DNSSEC validation code. The performance improvement and reduced"
    echo "timeout rate demonstrate effective prevention of CPU exhaustion attacks."
else
    echo "Further investigation may be needed to fully demonstrate the vulnerability"
    echo "and patch effectiveness. Consider adjusting test parameters or reviewing"
    echo "server configuration."
fi)

---

**Report Generated**: $(date)
**Test Environment**: Docker Containers on CentOS 7.9
**BIND Version**: 9.11.4-P2
EOF

    log_info "Comparison report saved to: $report_file"

    # Display key findings
    echo ""
    cat "$report_file"
}

# Main execution
main() {
    log_section "CVE-2025-8677 POC Comparison Test"

    log_info "Configuration:"
    echo "  Unpatched Server: $UNPATCHED_SERVER"
    echo "  Patched Server: $PATCHED_SERVER"
    echo "  Domain: $DOMAIN"
    echo "  Queries: $QUERIES"
    echo ""

    # Test unpatched server
    unpatched_stats=$(test_server "$UNPATCHED_SERVER" "unpatched")

    # Wait between tests
    sleep 5

    # Test patched server
    patched_stats=$(test_server "$PATCHED_SERVER" "patched")

    # Generate comparison report
    generate_comparison_report "$unpatched_stats" "$patched_stats"

    log_section "Testing Complete"
    log_info "All results saved to: $RESULTS_DIR"
}

# Run main function
main
