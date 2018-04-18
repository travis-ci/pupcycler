PACKAGE := github.com/travis-ci/pupcycler
ALL_PACKAGES := $(PACKAGE) $(PACKAGE)/cmd/...

VERSION_VAR := $(PACKAGE).VersionString
VERSION_VALUE ?= $(shell git describe --always --dirty --tags 2>/dev/null)
REV_VAR := $(PACKAGE).RevisionString
REV_VALUE ?= $(shell git rev-parse HEAD 2>/dev/null || echo "???")
REV_URL_VAR := $(PACKAGE).RevisionURLString
REV_URL_VALUE ?= https://$(PACKAGE)/tree/$(REV_VALUE)
GENERATED_VAR := $(PACKAGE).GeneratedString
GENERATED_VALUE ?= $(shell date -u +'%Y-%m-%dT%H:%M:%S%z')
COPYRIGHT_VAR := $(PACKAGE).CopyrightString
COPYRIGHT_VALUE ?= $(shell grep -i ^copyright LICENSE | sed 's/^[Cc]opyright //')

OS := $(shell uname | tr '[:upper:]' '[:lower:]')
ARCH := $(shell uname -m | if grep -q x86_64 ; then echo amd64 ; else uname -m ; fi)
GOPATH := $(shell go env GOPATH | sed 's/:.*//')
GOBUILD_LDFLAGS ?= \
	-X '$(VERSION_VAR)=$(VERSION_VALUE)' \
	-X '$(REV_VAR)=$(REV_VALUE)' \
	-X '$(REV_URL_VAR)=$(REV_URL_VALUE)' \
	-X '$(GENERATED_VAR)=$(GENERATED_VALUE)' \
	-X '$(COPYRIGHT_VAR)=$(COPYRIGHT_VALUE)'
DEPTOOLS := \
	$(GOPATH)/bin/gvt \
	$(GOPATH)/bin/gometalinter \
	$(GOPATH)/bin/checkmake

.PHONY: all
all: clean lint build test coverage.html crossbuild

.PHONY: test
test: deps
	go test -x -v -cover \
		-coverpkg $(PACKAGE) \
		-coverprofile coverage.txt \
		-ldflags "$(GOBUILD_LDFLAGS)" \
		$(PACKAGE)

coverage.html: coverage.txt
	go tool cover -html=$^ -o $@

.PHONY: listdeps
listdeps:
	@go list -f '{{ join .Imports "\n" }}' $(ALL_PACKAGES) | sort | uniq

.PHONY: lint
lint: deps
	./script/lint

.PHONY: build
build: deps
	go install -x -ldflags "$(GOBUILD_LDFLAGS)" $(ALL_PACKAGES)

.PHONY: crossbuild
crossbuild: deps
	GOARCH=amd64 GOOS=darwin CGO_ENABLED=0 go build -o build/darwin/amd64/pupcycler \
		-ldflags "$(GOBUILD_LDFLAGS)" $(PACKAGE)/cmd/pupcycler
	GOARCH=amd64 GOOS=linux CGO_ENABLED=0 go build -o build/linux/amd64/pupcycler \
		-ldflags "$(GOBUILD_LDFLAGS)" $(PACKAGE)/cmd/pupcycler

.PHONY: clean
clean:
	if [ -d $(GOPATH)/pkg ]; then find $(GOPATH)/pkg -wholename '*$(PACKAGE)*.a' -delete ; fi
	$(RM) $(GOPATH)/bin/pupcycler
	$(RM) -rv ./build coverage.html coverage.txt

.PHONY: distclean
distclean: clean
	$(RM) vendor/.deps-fetched

.PHONY: deps
deps: $(DEPTOOLS) vendor/.deps-fetched

vendor/.deps-fetched:
	gvt rebuild
	touch $@

.PHONY: dev-server
dev-server: $(GOPATH)/bin/reflex
	reflex -r '\.go$$' -s go run ./cmd/pupcycler/main.go serve

$(GOPATH)/bin/gvt:
	go get github.com/FiloSottile/gvt

$(GOPATH)/bin/checkmake:
	go get github.com/mrtazz/checkmake/...

$(GOPATH)/bin/gometalinter:
	go get github.com/alecthomas/gometalinter
	$@ --install

$(GOPATH)/bin/reflex:
	go get github.com/cespare/reflex
