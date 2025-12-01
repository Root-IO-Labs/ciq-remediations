#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "${SCRIPT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 {build-image|build-rpm|all|stop|clean|logs|list-rpms|shell}"
    echo ""
    echo "Commands:"
    echo "  build-image  - Build the Docker image"
    echo "  build-rpm    - Build BIND RPM packages"
    echo "  all          - Build image and RPM packages"
    echo "  stop         - Stop and remove container"
    echo "  clean        - Stop container and remove results"
    echo "  logs         - View build logs"
    echo "  list-rpms    - List generated RPM packages"
    echo "  shell        - Open shell in container"
    exit 1
}

build_image() {
    echo -e "${GREEN}Building Docker image for Rocky Linux 8.6...${NC}"
    docker-compose build
    echo -e "${GREEN}✅ Docker image built successfully${NC}"
}

build_rpm() {
    echo -e "${GREEN}Starting RPM build...${NC}"

    # Ensure container is running
    docker-compose up -d

    # Wait for container to be ready
    sleep 2

    # Execute build script
    echo -e "${YELLOW}Running build script inside container...${NC}"
    docker exec rocky8-bind-rpmbuild bash /root/build-bind-rpm.sh

    echo -e "${GREEN}✅ RPM build completed${NC}"
}

stop_container() {
    echo -e "${YELLOW}Stopping container...${NC}"
    docker-compose down
    echo -e "${GREEN}✅ Container stopped${NC}"
}

clean_all() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    docker-compose down
    rm -rf ../results/RPMS/* ../results/SRPMS/* ../results/*.log
    echo -e "${GREEN}✅ Cleanup completed${NC}"
}

view_logs() {
    if [ -f "../results/rpmbuild.log" ]; then
        less ../results/rpmbuild.log
    else
        echo -e "${RED}No build log found${NC}"
        exit 1
    fi
}

list_rpms() {
    echo ""
    echo "Binary RPMs:"
    echo "============"
    ls -lh ../results/RPMS/ 2>/dev/null || echo "No binary RPMs found"

    echo ""
    echo "Source RPMs:"
    echo "============"
    ls -lh ../results/SRPMS/ 2>/dev/null || echo "No source RPMs found"
    echo ""
}

open_shell() {
    docker-compose up -d
    docker exec -it rocky8-bind-rpmbuild bash
}

# Main script
case "${1}" in
    build-image)
        build_image
        ;;
    build-rpm)
        build_rpm
        ;;
    all)
        build_image
        build_rpm
        list_rpms
        ;;
    stop)
        stop_container
        ;;
    clean)
        clean_all
        ;;
    logs)
        view_logs
        ;;
    list-rpms)
        list_rpms
        ;;
    shell)
        open_shell
        ;;
    *)
        usage
        ;;
esac
