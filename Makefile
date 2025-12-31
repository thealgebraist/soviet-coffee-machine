.PHONY: all build wasm clean setup setup-zig setup-mojo setup-local check-versions test test-conda test-run-local run-server run-mojo gen-image gen-tts gen-sfx

all: build wasm

# ... (rest of the file handles build) ...

setup-mojo:
	@echo "Setting up Mojo environment..."
	bash server/mojo_setup.sh

run-mojo:
	@echo "Running Mojo Crema Optimizer..."
	@cd mojo_project && magic run mojo hello.mojo

# --- Build Logic ---
build:
	@echo "Building Zig WASM module..."
	zig build
	@mkdir -p www
	cp zig-out/bin/game.wasm www/game.wasm

wasm: build

clean:
	rm -rf zig-out .zig-cache www/game.wasm

# --- Environment & Testing ---

setup:
	@echo "Running vast_setup.sh..."
	bash server/vast_setup.sh

setup-zig:
	@echo "Installing Zig 0.15.2 for Linux x86_64..."
	curl -L https://ziglang.org/download/0.15.2/zig-x86_64-linux-0.15.2.tar.xz -o zig.tar.xz
	tar -xf zig.tar.xz
	mv zig-x86_64-linux-0.15.2 zig-linux
	@echo "Zig installed to ./zig-linux/zig"
	@echo "Update your PATH: export PATH=\$$PATH:\$$(pwd)/zig-linux"

setup-local:
	@echo "Running local_setup.sh for this machine..."
	bash server/local_setup.sh

check-versions:
	@echo "--- Environment Check ---"
	@if ! command -v conda &> /dev/null; then echo "ERROR: conda not found"; exit 1; fi
	@echo "Conda version: $$(conda --version)"
	@# Attempt to run check in coffee_env if it exists
	@if conda info --envs | grep -q $(CONDA_ENV); then \
		echo "Checking $(CONDA_ENV) environment..."; \
		conda run -n $(CONDA_ENV) python --version; \
		conda run -n $(CONDA_ENV) python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.version.cuda}'); print(f'GPU Available: {torch.cuda.is_available()}')"; \
	else \
		echo "WARNING: Conda environment $(CONDA_ENV) not found. Run 'make setup' first."; \
	fi

test: check-versions test-conda
	@echo "--- Project Test ---"
	@if [ -f www/game.wasm ]; then echo "[PASS] game.wasm exists"; else echo "[FAIL] game.wasm missing"; exit 1; fi
	@if [ -f www/index.html ]; then echo "[PASS] HTML assets present"; else echo "[FAIL] HTML assets missing"; exit 1; fi
	@echo "--- All Tests Passed ---"

test-conda:
	@echo "--- Running Conda Suite ---"
	@if conda info --envs | grep -q $(CONDA_ENV); then \
		conda run -n $(CONDA_ENV) python server/test_conda.py; \
	else \
		echo "Testing with local python path..."; \
		python3 server/test_conda.py || (echo "Conda env not found and local test failed."; exit 1); \
	fi
test-run-local:
	@echo "--- Attempting Local Run (Conda + Model Test) ---"
	@echo "1. Attempting Setup..."
	-timeout -s 9 5s make setup || echo "[INFO] Setup timed out or failed as expected on local guest."
	@echo "2. Attempting Conda Test..."
	-make test-conda || echo "[INFO] Conda test failed as expected (missing packages)."
	@echo "--- Local Run Attempt Finished ---"

setup-cpp:
	@echo "Setting up C++ Media Server Workspace..."
	bash server/cpp/setup_cpp_deps.sh

build-cpp:
	@echo "Building C++ Media Server..."
	@mkdir -p server/cpp/build
	@cd server/cpp/build && cmake .. && make

run-server-cpp:
	@echo "Starting Soviet C++ Media Server..."
	./server/cpp/build/generator_server

gen-image:
	@if [ -z "$(PROMPT)" ]; then echo "Usage: make gen-image PROMPT='your prompt'"; exit 1; fi
	curl -X POST http://localhost:8000/generate \
		-H "Content-Type: application/json" \
		-d "{\"image_prompt\": \"$(PROMPT)\"}"

gen-tts:
	@if [ -z "$(PROMPT)" ]; then echo "Usage: make gen-tts PROMPT='your prompt'"; exit 1; fi
	curl -X POST http://localhost:8000/generate \
		-H "Content-Type: application/json" \
		-d "{\"tts_prompt\": \"$(PROMPT)\"}"

gen-sfx:
	@if [ -z "$(PROMPT)" ]; then echo "Usage: make gen-sfx PROMPT='your prompt'"; exit 1; fi
	curl -X POST http://localhost:8000/generate \
		-H "Content-Type: application/json" \
		-d "{\"sfx_prompt\": \"$(PROMPT)\"}"
