#!/bin/bash
set -e

echo "============================================================"
echo "Rocky Linux 8.6 BIND 9.11.36 RPM Build with CVE-2025-8677 Patch"
echo "============================================================"
echo ""

BIND_VERSION="9.11.36"
BIND_RELEASE="16.el8_10.6"
RPMBUILD_DIR="${HOME}/rpmbuild"

echo "Step 1: Download BIND source RPM from Rocky Linux repository"
echo "------------------------------------------------------------"
echo "Note: Using BIND 9.11.36-16.el8_10.6 from Rocky Linux 8"
echo "      This is the latest BIND 9.11 in Rocky Linux 8"

# Rocky Linux 8 BIND 9.11.36 SRPM location
SRPM_URL="https://download.rockylinux.org/pub/rocky/8/BaseOS/source/tree/Packages/b/bind-${BIND_VERSION}-${BIND_RELEASE}.src.rpm"

cd ${RPMBUILD_DIR}/SRPMS

if [ ! -f "bind-${BIND_VERSION}-${BIND_RELEASE}.src.rpm" ]; then
    echo "Downloading BIND ${BIND_VERSION} SRPM..."
    wget "${SRPM_URL}" || {
        echo "ERROR: Failed to download SRPM from ${SRPM_URL}"
        echo "Trying Rocky 8.6 vault..."
        # Try Rocky 8.6 vault
        wget "https://download.rockylinux.org/vault/rocky/8.6/BaseOS/source/tree/Packages/b/bind-${BIND_VERSION}-3.el8_6.1.src.rpm" || {
            echo "ERROR: Could not download SRPM from any source"
            echo "Please check available versions at:"
            echo "  https://download.rockylinux.org/pub/rocky/8/BaseOS/source/tree/Packages/b/"
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

# Get the actual SRPM filename that was downloaded
SRPM_FILE=$(ls -t bind-${BIND_VERSION}-*.src.rpm 2>/dev/null | head -1)

if [ -z "${SRPM_FILE}" ]; then
    echo "ERROR: No BIND SRPM found in ${RPMBUILD_DIR}/SRPMS/"
    exit 1
fi

echo "Installing SRPM: ${SRPM_FILE}"
rpm -ivh "${SRPM_FILE}" || {
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

# Install dependencies manually (excluding kyua and softhsm which are unavailable in Rocky 8)
echo "Installing build dependencies (excluding unavailable kyua and softhsm)..."

dnf install -y \
    autoconf \
    automake \
    docbook-style-xsl \
    fstrm-devel \
    json-c-devel \
    krb5-devel \
    libcap-devel \
    libcmocka-devel \
    libdb-devel \
    libidn2-devel \
    libmaxminddb-devel \
    libtool \
    libxml2-devel \
    libxslt \
    lmdb-devel \
    mariadb-connector-c-devel \
    openldap-devel \
    openssl-devel \
    pkgconfig \
    postgresql-devel \
    protobuf-c-devel \
    python3 \
    python3-devel \
    python3-ply \
    sqlite-devel \
    systemd-devel \
    zlib-devel

echo "✅ Build dependencies installed (kyua and softhsm not available in Rocky 8 - tests skipped)"
echo ""

echo "Step 3.5: Remove unavailable BuildRequires from spec file"
echo "------------------------------------------------------------"
cd ${RPMBUILD_DIR}/SPECS

# Remove kyua and softhsm from BuildRequires since they're not available in Rocky 8
sed -i '/^BuildRequires:.*kyua/d' bind.spec
sed -i '/^BuildRequires:.*softhsm/d' bind.spec

echo "✅ Removed unavailable BuildRequires (kyua, softhsm)"
echo ""

echo "Step 4: Apply CVE-2025-8677 security patch"
echo "------------------------------------------------------------"

# Check if BIND 9.11.36-specific patch is mounted
if [ -f "/patches/CVE-2025-8677-bind-9.11.36.patch" ]; then
    echo "Found CVE-2025-8677 BIND 9.11.36-specific patch"
    PATCH_FILE="CVE-2025-8677-bind-9.11.36.patch"
    cp /patches/CVE-2025-8677-bind-9.11.36.patch ${RPMBUILD_DIR}/SOURCES/
else
    echo "⚠️  ERROR: CVE-2025-8677 patch not found at /patches/CVE-2025-8677-bind-9.11.36.patch"
    echo "This patch is required for BIND 9.11.36"
    exit 1
fi

# If patch was found, add it to spec file
if [ -n "${PATCH_FILE}" ]; then
    # Add patch to spec file
    cd ${RPMBUILD_DIR}/SPECS

    # Backup original spec file
    cp bind.spec bind.spec.original

    # Find highest patch number
    MAX_PATCH=$(grep "^Patch[0-9]*:" bind.spec | sed 's/Patch\([0-9]*\):.*/\1/' | sort -n | tail -1)
    NEXT_PATCH=$((MAX_PATCH + 1))

    echo "Highest existing patch: Patch${MAX_PATCH}"
    echo "Adding CVE-2025-8677 patch as Patch${NEXT_PATCH}"

    # Add patch declaration after last Patch line
    LAST_PATCH_LINE=$(grep -n "^Patch[0-9]*:" bind.spec | tail -1 | cut -d: -f1)
    sed -i "${LAST_PATCH_LINE}a Patch${NEXT_PATCH}: ${PATCH_FILE}" bind.spec

    # Add patch application in %prep section (after all other patches)
    # Rocky 8 uses newer RPM requiring new patch syntax: %patch -P NUMBER
    LAST_PATCH_APP_LINE=$(grep -n "^%patch" bind.spec | tail -1 | cut -d: -f1)
    sed -i "${LAST_PATCH_APP_LINE}a %patch -P ${NEXT_PATCH} -p1 -b .cve-2025-8677" bind.spec

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
echo "Note: Skipping %check phase (tests) since softhsm2 is not available"

rpmbuild -ba --nocheck bind.spec 2>&1 | tee /results/rpmbuild.log

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

    # Copy RPMs to results directory
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
