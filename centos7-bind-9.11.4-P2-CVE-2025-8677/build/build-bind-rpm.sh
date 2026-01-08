#!/bin/bash
set -e

echo "============================================================"
echo "CentOS 7.9 BIND 9.11.4-P2 RPM Build with CVE-2025-8677 Patch"
echo "============================================================"
echo ""

BIND_VERSION="9.11.4"
BIND_RELEASE="26.P2.el7_9.16"
RPMBUILD_DIR="${HOME}/rpmbuild"

echo "Step 1: Download BIND source RPM from CentOS vault"
echo "------------------------------------------------------------"

# CentOS 7.9 BIND 9.11.4-P2 SRPM location
SRPM_URL="http://vault.centos.org/centos/7/updates/Source/SPackages/bind-${BIND_VERSION}-${BIND_RELEASE}.src.rpm"

cd ${RPMBUILD_DIR}/SRPMS

if [ ! -f "bind-${BIND_VERSION}-${BIND_RELEASE}.src.rpm" ]; then
    echo "Downloading BIND SRPM..."
    wget "${SRPM_URL}" || {
        echo "ERROR: Failed to download SRPM from ${SRPM_URL}"
        echo "Trying alternative URL..."
        # Try alternative location
        wget "http://vault.centos.org/7.9.2009/updates/Source/SPackages/bind-${BIND_VERSION}-${BIND_RELEASE}.src.rpm" || {
            echo "ERROR: Could not download SRPM from any source"
            exit 1
        }
    }
    echo "✅ SRPM downloaded successfully"
else
    echo "✅ SRPM already exists"
fi

echo ""
echo "Step 2: Install SRPM (extracts to rpmbuild directories)"
echo "------------------------------------------------------------"

rpm -ivh "bind-${BIND_VERSION}-${BIND_RELEASE}.src.rpm" || {
    echo "Note: SRPM may already be installed"
}

echo "✅ SRPM installed"
echo ""

# List what was extracted
echo "Extracted files in SOURCES:"
ls -lh ${RPMBUILD_DIR}/SOURCES/ | head -20

echo ""
echo "Spec file:"
ls -lh ${RPMBUILD_DIR}/SPECS/bind.spec

echo ""
echo "Step 3: Install build dependencies"
echo "------------------------------------------------------------"

yum-builddep -y ${RPMBUILD_DIR}/SPECS/bind.spec || {
    echo "Note: Some dependencies may already be installed"
}

echo "✅ Build dependencies installed"
echo ""

echo "Step 4: Apply CVE-2025-8677 security patch"
echo "------------------------------------------------------------"

# Check if patch is mounted/available
# Try CentOS-adapted patch first, fall back to original
if [ -f "/patches/CVE-2025-8677-centos-adapted.patch" ]; then
    echo "Found CVE-2025-8677 CentOS-adapted patch"
    PATCH_FILE="CVE-2025-8677-centos-adapted.patch"
    # Copy patch to SOURCES directory
    cp /patches/CVE-2025-8677-centos-adapted.patch ${RPMBUILD_DIR}/SOURCES/
else
    echo "⚠️  WARNING: CVE-2025-8677 patch not found at /patches/"
    echo "Continuing without security patch..."
    PATCH_FILE=""
fi

# If patch was found, add it to spec file
if [ -n "${PATCH_FILE}" ]; then
    # Add patch to spec file
    cd ${RPMBUILD_DIR}/SPECS

    # Backup original spec file
    cp bind.spec bind.spec.original

    # Find highest patch number (not count)
    MAX_PATCH=$(grep "^Patch[0-9]*:" bind.spec | sed 's/Patch\([0-9]*\):.*/\1/' | sort -n | tail -1)
    NEXT_PATCH=$((MAX_PATCH + 1))

    echo "Highest existing patch: Patch${MAX_PATCH}"
    echo "Adding CVE-2025-8677 patch as Patch${NEXT_PATCH}"

    # Add patch declaration after last Patch line
    # Find line number of last patch declaration
    LAST_PATCH_LINE=$(grep -n "^Patch[0-9]*:" bind.spec | tail -1 | cut -d: -f1)
    sed -i "${LAST_PATCH_LINE}a Patch${NEXT_PATCH}: ${PATCH_FILE}" bind.spec

    # Add patch application in %prep section (after all other patches)
    # Find the last %patch application line in the spec file
    LAST_PATCH_APP_LINE=$(grep -n "^%patch[0-9]" bind.spec | tail -1 | cut -d: -f1)
    sed -i "${LAST_PATCH_APP_LINE}a %patch${NEXT_PATCH} -p1 -b .cve-2025-8677" bind.spec

    echo "✅ Patch added to spec file"

    echo ""
    echo "Modified spec file (showing patch section):"
    grep -A 2 -B 2 "CVE-2025-8677" bind.spec || echo "Patch added"
fi

echo ""
echo "Step 5: Build BIND RPM packages"
echo "------------------------------------------------------------"

cd ${RPMBUILD_DIR}/SPECS

echo "Building RPMs (this may take 10-20 minutes)..."

rpmbuild -ba bind.spec 2>&1 | tee /results/rpmbuild.log

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================================"
    echo "✅ BUILD SUCCESSFUL!"
    echo "============================================================"
    echo ""

    echo "Generated RPM packages:"
    echo ""
    echo "Binary RPMs:"
    ls -lh ${RPMBUILD_DIR}/RPMS/*/*.rpm 2>/dev/null || echo "No binary RPMs found"
    echo ""
    echo "Source RPMs:"
    ls -lh ${RPMBUILD_DIR}/SRPMS/*.rpm 2>/dev/null || echo "No source RPMs found"
    echo ""

    # Copy RPMs to results directory for easy access
    echo "Copying RPMs to /results/..."
    mkdir -p /results/RPMS /results/SRPMS
    cp -v ${RPMBUILD_DIR}/RPMS/*/*.rpm /results/RPMS/ 2>/dev/null || true
    cp -v ${RPMBUILD_DIR}/SRPMS/*.rpm /results/SRPMS/ 2>/dev/null || true

    echo ""
    echo "RPMs are available in:"
    echo "  - ${RPMBUILD_DIR}/RPMS/"
    echo "  - ${RPMBUILD_DIR}/SRPMS/"
    echo "  - /results/RPMS/"
    echo "  - /results/SRPMS/"

else
    echo ""
    echo "============================================================"
    echo "❌ BUILD FAILED"
    echo "============================================================"
    echo ""
    echo "Check the build log at: /results/rpmbuild.log"
    echo ""
    echo "Last 50 lines of build output:"
    tail -50 /results/rpmbuild.log
    exit 1
fi

echo ""
echo "============================================================"
echo "Build complete!"
echo "============================================================"
