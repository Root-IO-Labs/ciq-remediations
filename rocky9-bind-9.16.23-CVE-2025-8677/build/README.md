# Rocky Linux 9 BIND 9.16.23 - Rebuild Instructions

This directory contains all files needed to rebuild the BIND RPM packages with the CVE-2025-8677 security patch from source.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB free disk space
- Internet connection (to download source RPMs)
- **ARM64 (aarch64) architecture** (or modify Dockerfile for x86_64)

## Quick Rebuild

```bash
cd build/
./run-rpmbuild.sh all
```

This will:
1. Build the Docker image (Rocky Linux 9 RPM build environment)
2. Start the build container
3. Download BIND 9.16.23 source RPM
4. Apply CVE-2025-8677 patch from `../patches/`
5. Build all BIND RPM packages
6. Copy results to `build/results/`

## Build Output

After successful build, RPMs will be in:
- `build/results/RPMS/` - Binary RPM packages (15 packages, aarch64)
- `build/results/SRPMS/` - Source RPM packages
- `build/results/rpmbuild.log` - Full build log

## Individual Build Steps

```bash
# 1. Build Docker image only
./run-rpmbuild.sh build-image

# 2. Start container
./run-rpmbuild.sh start

# 3. Run build in container
./run-rpmbuild.sh build-rpm

# 4. Open shell in container (for debugging)
./run-rpmbuild.sh shell

# 5. Stop container
./run-rpmbuild.sh stop

# 6. Clean up everything
./run-rpmbuild.sh clean
```

## What Gets Patched

The build process:
1. Downloads official Rocky Linux 9 BIND 9.16.23 source RPM
2. Applies `CVE-2025-8677-bind-9.16.23-security-fix.patch` from `../patches/`
3. Modifies `bind.spec` to include the security patch
4. Builds all BIND packages with the fix

## Patch Details

**Patch File**: `../patches/CVE-2025-8677-bind-9.16.23-security-fix.patch`

The patch adds 5 changes to `lib/dns/validator.c`:
- Fix #1: Add `#include <dst/result.h>` (line 42) - **BIND 9.16.x specific**
- Fix #2: Selective error handling for key selection (line ~1280)
- Fix #3: First `dns_dnssec_keyfromrdata()` check (line ~1399)
- Fix #4: Second key processing verification (line ~1418)

**Strategy**: Selective fail-fast approach optimized for BIND 9.16.x
- Distinguishes `ISC_R_NOTFOUND` (expected) from critical errors
- More targeted than 9.11.x comprehensive approach

## BIND 9.16.x Differences

Unlike BIND 9.11.x (CentOS 7, Rocky 8), this patch:
- ✅ Requires explicit `#include <dst/result.h>`
- ✅ Uses selective error checking (not fail-on-all)
- ✅ Allows `ISC_R_NOTFOUND` to continue (expected case)
- ✅ Fails fast only on critical errors

## Verification

After rebuild, verify the patch was applied:

```bash
# Check RPM changelog
rpm -qp --changelog results/RPMS/aarch64/bind-9.16.23-*.rpm | head -20

# Should show CVE-2025-8677 entry
```

## Troubleshooting

**Build fails at download step**:
- Rocky Linux mirrors may be slow
- Script tries multiple mirrors automatically
- Check internet connection

**Build fails at compile step**:
- Check `results/rpmbuild.log` for errors
- Ensure sufficient disk space (4GB+)
- Try: `./run-rpmbuild.sh clean` then rebuild

**Patch not applied**:
- Verify patch exists: `ls -lh ../patches/CVE-2025-8677-bind-9.16.23-security-fix.patch`
- Check docker-compose.yml mounts patches correctly
- Container sees patch at: `/patches/CVE-2025-8677-bind-9.16.23-security-fix.patch`

**Wrong architecture**:
- These RPMs are for **aarch64 (ARM64)**
- Check: `uname -m` should show `aarch64`
- For x86_64: Modify Dockerfile base image or rebuild from SRPM

## Architecture

**Target**: aarch64 (ARM64)

Supported platforms:
- Apple Silicon (M1/M2/M3 Macs)
- ARM-based servers
- AWS Graviton instances
- Raspberry Pi 4/5 (64-bit)

**For x86_64**: You need to rebuild from source SRPM on x86_64 system.

## Build Time

Typical build time: **15-25 minutes** (depending on system)
- Similar to Rocky 8
- Fewer packages (15 vs 27) but modern build system

## Rocky Linux 9 Specifics

- Uses DNF instead of YUM
- Modern BIND 9.16.x architecture
- More refined error handling patterns
- Streamlined package structure (15 RPMs)
- Native Python 3 support

## Support

For issues with the CVE-2025-8677 patch or build process, see:
- Main documentation: `../README.md`
- Patch details: `../docs/CVE-2025-8677-Complete-Fix-Guide.md`

---

**Build Environment**: Rocky Linux 9 (Docker container)
**BIND Version**: 9.16.23-31.el9
**Architecture**: aarch64 (ARM64)
**Patch**: CVE-2025-8677 security fix (selective fail-fast)
