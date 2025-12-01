#!/bin/bash

# CentOS 7.9 BIND RPM Build Runner
# Automated script to build BIND 9.11.4-P2 RPM with CVE-2025-8677 patch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

ACTION="${1:-all}"

echo "============================================================"
echo "CentOS 7.9 BIND 9.11.4-P2 RPM Build Runner"
echo "============================================================"
echo ""

case "${ACTION}" in
    "build-image")
        echo "Building Docker image..."
        docker-compose build --no-cache
        echo "✅ Docker image built"
        ;;

    "start")
        echo "Starting RPM build container..."
        docker-compose up -d
        echo "✅ Container started"
        echo ""
        echo "To enter the container:"
        echo "  docker exec -it centos7-bind-rpmbuild bash"
        echo ""
        echo "To run the build:"
        echo "  docker exec -it centos7-bind-rpmbuild bash /root/build-bind-rpm.sh"
        ;;

    "build-rpm")
        echo "Running RPM build in container..."
        docker-compose up -d
        sleep 2
        docker exec centos7-bind-rpmbuild bash /root/build-bind-rpm.sh
        echo ""
        echo "✅ Build completed"
        echo ""
        echo "RPMs are in: ../results/RPMS/"
        ;;

    "shell")
        echo "Opening shell in build container..."
        docker-compose up -d
        docker exec -it centos7-bind-rpmbuild bash
        ;;

    "stop")
        echo "Stopping container..."
        docker-compose down
        echo "✅ Container stopped"
        ;;

    "clean")
        echo "Cleaning up Docker resources..."
        docker-compose down -v
        echo "Cleaning results directory..."
        rm -rf ../results/*
        echo "✅ Cleanup complete"
        ;;

    "logs")
        echo "Showing build logs..."
        if [ -f "../results/rpmbuild.log" ]; then
            less ../results/rpmbuild.log
        else
            echo "No build log found. Run build first."
        fi
        ;;

    "list-rpms")
        echo "Generated RPM packages:"
        echo ""
        if [ -d "../results/RPMS" ]; then
            ls -lh ../results/RPMS/
        else
            echo "No RPMs found. Run build first."
        fi
        ;;

    "all")
        echo "Running full RPM build process..."
        echo ""

        echo "Step 1/4: Building Docker image..."
        docker-compose build --no-cache
        echo "✅ Image built"
        echo ""

        echo "Step 2/4: Starting container..."
        docker-compose up -d
        sleep 2
        echo "✅ Container started"
        echo ""

        echo "Step 3/4: Running RPM build..."
        docker exec centos7-bind-rpmbuild bash /root/build-bind-rpm.sh
        echo ""

        echo "Step 4/4: Listing generated RPMs..."
        echo ""
        ls -lh ../results/RPMS/ 2>/dev/null || echo "Check ../results/ directory"
        echo ""

        echo "============================================================"
        echo "✅ Complete RPM build process finished!"
        echo "============================================================"
        echo ""
        echo "RPMs available in: ../results/RPMS/"
        echo "Build log: ../results/rpmbuild.log"
        echo ""
        echo "To stop container: $0 stop"
        ;;

    *)
        echo "CentOS 7.9 BIND RPM Build Runner"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  all          - Full build process (build image + build RPM) [default]"
        echo "  build-image  - Build Docker image only"
        echo "  build-rpm    - Build RPM packages"
        echo "  start        - Start container (without building)"
        echo "  shell        - Open shell in container"
        echo "  stop         - Stop container"
        echo "  clean        - Remove all Docker resources and results"
        echo "  logs         - View build logs"
        echo "  list-rpms    - List generated RPM packages"
        echo ""
        echo "Examples:"
        echo "  $0 all           # Full automated build"
        echo "  $0 build-rpm     # Build RPMs"
        echo "  $0 shell         # Interactive shell"
        echo "  $0 list-rpms     # See generated RPMs"
        exit 1
        ;;
esac
