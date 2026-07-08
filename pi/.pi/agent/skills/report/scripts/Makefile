BINARY := mdreport

.PHONY: build clean

build: $(BINARY)

$(BINARY): main.go go.mod go.sum
	go build -o $(BINARY) .

clean:
	rm -f $(BINARY)
