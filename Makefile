# Makefile for building and running the MkDocs Docker container

# Variables
IMAGE_NAME = mk-local
CONTAINER_PORT = 8000
HOST_PORT = 8000
DOCKERFILE = Dockerfile
DOCS_DIR = $(PWD)

# Targets
.PHONY: all build run clean

# Default target
all: build run

# Build the Docker image
build:
	docker build -f $(DOCKERFILE) -t $(IMAGE_NAME) .

# Run the Docker container
run:
	docker run --rm -it -p $(HOST_PORT):$(CONTAINER_PORT) -v $(DOCS_DIR):/docs $(IMAGE_NAME)

# Clean up Docker images
clean:
	docker rmi $(IMAGE_NAME)