.DEFAULT_GOAL := test

PORT ?= 8000
BUILD_DIR := docs/_build/html

.PHONY: build test

build:
	uv run --frozen --group dev sphinx-build -b html docs $(BUILD_DIR)

test: build
	@echo "Preview: http://localhost:$(PORT) (Ctrl+C to stop)"
	uv run --frozen --group dev python -m http.server $(PORT) --bind 127.0.0.1 --directory $(BUILD_DIR)
