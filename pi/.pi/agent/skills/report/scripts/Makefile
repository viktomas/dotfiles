BINARY := mdreport

.PHONY: build clean

build: $(BINARY)

$(BINARY): main.go annotations.css annotations.js go.mod go.sum
	go build -o $(BINARY) .

clean:
	rm -f $(BINARY)
