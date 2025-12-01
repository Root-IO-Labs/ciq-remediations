#!/bin/bash

case "$1" in
    start)
        echo "Starting Rocky 9.2 BIND RPM build container..."
        docker compose up -d
        echo "✅ Container started"
        echo ""
        echo "To run the build:"
        echo "  docker exec rocky9-bind-rpmbuild bash /root/build-bind-rpm.sh"
        ;;
    stop)
        echo "Stopping container..."
        docker compose down
        echo "✅ Container stopped"
        ;;
    build)
        echo "Running BIND RPM build..."
        docker exec rocky9-bind-rpmbuild bash /root/build-bind-rpm.sh
        ;;
    shell)
        echo "Opening shell in container..."
        docker exec -it rocky9-bind-rpmbuild /bin/bash
        ;;
    all)
        echo "Building Docker image and starting container..."
        docker compose up -d --build
        echo "✅ Container ready"
        echo ""
        echo "Running BIND RPM build..."
        docker exec rocky9-bind-rpmbuild bash /root/build-bind-rpm.sh
        ;;
    *)
        echo "Usage: $0 {start|stop|build|shell|all}"
        echo ""
        echo "Commands:"
        echo "  start - Start the container"
        echo "  stop  - Stop and remove the container"
        echo "  build - Run the RPM build in existing container"
        echo "  shell - Open an interactive shell in the container"
        echo "  all   - Build image, start container, and run build"
        exit 1
        ;;
esac
