BUILD_ARGS := $(BUILD_ARGS)
VERSION := $(or $(VERSION),$(VERSION),4.16.0)
BASE_VERSION := $(or $(BASE_VERSION),$(BASE_VERSION),4.16.0)
PLATFORMS := $(or $(PLATFORMS),$(PLATFORMS),linux/arm64)

build-docker:
	docker build $(BUILD_ARGS) --build-arg VERSION=$(BASE_VERSION) --build-arg RELEASE=$(BASE_RELEASE) -t noxymon/automation-selenium:21-bookworm .
build-multi-arch:
	docker buildx build --push --platform linux/amd64,linux/arm64 $(BUILD_ARGS) --build-arg VERSION=$(BASE_VERSION) --build-arg RELEASE=$(BASE_RELEASE) -t noxymon/automation-selenium:21-bookworm .

