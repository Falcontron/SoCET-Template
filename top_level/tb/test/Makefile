CXX = g++
CXXFLAGS = -std=c++20 -Wall -Wextra -I../util -I../sim-peripherals

BUILD_DIR = build

SOURCES = $(wildcard *.cc)
TARGETS = $(patsubst %.cc,$(BUILD_DIR)/%,$(SOURCES))

all: $(TARGETS)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%: %.cc | $(BUILD_DIR)
	$(CXX) $(CXXFLAGS) -o $@ $<

run: $(TARGETS)
	./run.sh $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all run clean

info:
	@echo "Sources found: $(SOURCES)"
	@echo "Targets to build: $(TARGETS)"

.PHONY: info
