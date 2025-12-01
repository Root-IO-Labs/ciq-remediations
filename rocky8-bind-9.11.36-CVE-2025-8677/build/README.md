# Rocky Linux 8 BIND 9.11.36 - Rebuild Instructions

This directory contains all files needed to rebuild the BIND RPM packages with the CVE-2025-8677 security patch from source.

## Prerequisites

- Docker and Docker Compose installed
- At least 4GB free disk space
- Internet connection (to download source RPMs)

## Quick Rebuild

```bash
cd build/
./run-rpmbuild.sh all
```

This will:
1. Build the Docker image (Rocky Linux 8 RPM build environment)
2. Start the build container
3. Download BIND 9.11.36 source RPM
4. Apply CVE-2025-8677 patch from `../patches/`
5. Build all BIND RPM packages
6. Copy results to `build/results/`

## Build Output

After successful build, RPMs will be in:
- `build/results/RPMS/` - Binary RPM packages (27 packages)
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
1. Downloads official Rocky Linux 8 BIND 9.11.36 source RPM
2. Applies `CVE-2025-8677-bind-9.11.36.patch` from `../patches/`
3. Modifies `bind.spec` to include the security patch
4. Builds all BIND packages with the fix

## Patch Details

**Patch File**: `../patches/CVE-2025-8677-bind-9.11.36.patch`

The patch adds 4 security fixes to `lib/dns/validator.c`:
- Fix #1: Error check after `dst_key_free()` (line ~1280)
- Fix #2: Refine error handling for key selection
- Fix #3: First `dns_dnssec_keyfromrdata()` check (line ~1399)
- Fix #4: Second key processing verification (line ~1418)

**Strategy**: Comprehensive fail-on-all-errors approach for BIND 9.11.x

## Verification

After rebuild, verify the patch was applied:

```bash
# Check RPM changelog
rpm -qp --changelog results/RPMS/x86_64/bind-9.11.36-*.rpm | head -20

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
- Verify patch exists: `ls -lh ../patches/CVE-2025-8677-bind-9.11.36.patch`
- Check docker-compose.yml mounts patches correctly
- Container sees patch at: `/patches/CVE-2025-8677-bind-9.11.36.patch`

**Missing build dependencies**:
- Rocky 8 may not have `kyua` or `softhsm` packages
- Build script handles this automatically
- Tests requiring these tools will be skipped

## Architecture

**Target**: x86_64 (Intel/AMD 64-bit)

If you need to build for a different architecture, modify the Dockerfile and rebuild.

## Build Time

Typical build time: **15-25 minutes** (depending on system)
- Longer than CentOS 7 due to more packages (27 vs 17)
- More comprehensive test suite

## Rocky Linux 8 Specifics

- Uses DNF instead of YUM
- More modular package structure (27 RPMs)
- Includes Python 3 bindings
- GeoIP2 support (maxminddb)
- JSON-C statistics output

## Support

For issues with the CVE-2025-8677 patch or build process, see:
- Main documentation: `../README.md`
- Patch details: `../docs/CVE-2025-8677-Complete-Fix-Guide.md`

---

**Build Environment**: Rocky Linux 8 (Docker container)
**BIND Version**: 9.11.36-16.el8_10.6
**Patch**: CVE-2025-8677 security fix
