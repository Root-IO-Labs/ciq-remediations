# CentOS 7.9 BIND 9.11.4-P2 - Rebuild Instructions

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
1. Build the Docker image (CentOS 7.9 RPM build environment)
2. Start the build container
3. Download BIND 9.11.4-P2 source RPM
4. Apply CVE-2025-8677 patch from `../patches/`
5. Build all BIND RPM packages
6. Copy results to `build/results/`

## Build Output

After successful build, RPMs will be in:
- `build/results/RPMS/` - Binary RPM packages
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
1. Downloads official CentOS 7.9 BIND 9.11.4-P2 source RPM
2. Applies `CVE-2025-8677-bind-9.11.4-P2.patch` from `../patches/`
3. Modifies `bind.spec` to include the security patch
4. Builds all BIND packages with the fix

## Patch Details

**Patch File**: `../patches/CVE-2025-8677-bind-9.11.4-P2.patch`

The patch adds 4 security fixes to `lib/dns/validator.c`:
- Fix #1: Error check after `dst_key_free()` (line ~1280)
- Fix #2: Refine error handling for key selection
- Fix #3: First `dns_dnssec_keyfromrdata()` check (line ~1399)
- Fix #4: Second key processing verification (line ~1418)

## Verification

After rebuild, verify the patch was applied:

```bash
# Check RPM changelog
rpm -qp --changelog results/RPMS/x86_64/bind-9.11.4-*.rpm | head -20

# Should show CVE-2025-8677 entry
```

## Troubleshooting

**Build fails at download step**:
- CentOS 7 mirrors may be slow
- Script tries vault.centos.org automatically
- Check internet connection

**Build fails at compile step**:
- Check `results/rpmbuild.log` for errors
- Ensure sufficient disk space (4GB+)
- Try: `./run-rpmbuild.sh clean` then rebuild

**Patch not applied**:
- Verify patch exists: `ls -lh ../patches/CVE-2025-8677-bind-9.11.4-P2.patch`
- Check docker-compose.yml mounts patches correctly
- Container sees patch at: `/patches/CVE-2025-8677-bind-9.11.4-P2.patch`

## Architecture

**Target**: x86_64 (Intel/AMD 64-bit)

If you need to build for a different architecture, modify the Dockerfile and rebuild.

## Build Time

Typical build time: **10-20 minutes** (depending on system)

## Support

For issues with the CVE-2025-8677 patch or build process, see:
- Main documentation: `../README.md`
- Patch details: `../docs/CVE-2025-8677-Complete-Fix-Guide.md`

---

**Build Environment**: CentOS 7.9.2009 (Docker container)
**BIND Version**: 9.11.4-P2-26.el7_9.16
**Patch**: CVE-2025-8677 security fix
