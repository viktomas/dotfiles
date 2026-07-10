BINARY := mdreport
PREFIX := $(HOME)/bin

.PHONY: build install clean

build: $(BINARY)

$(BINARY): main.go annotations.css annotations.js go.mod go.sum
	go build -o $(BINARY) .

install: build
	mkdir -p $(PREFIX)
	ln -sf $(CURDIR)/$(BINARY) $(PREFIX)/$(BINARY)

clean:
	rm -f $(BINARY)
