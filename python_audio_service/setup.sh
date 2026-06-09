#!/bin/bash
set -e

echo "=== Aureon Python Setup — 100% Free Stack ==="

# Python venv
echo "Creating virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# System tools
echo ""
echo "Checking system dependencies..."
for cmd in ffmpeg sox rubberband; do
    if command -v "$cmd" &>/dev/null; then
        echo "  ✓ $cmd"
    else
        echo "  ✗ $cmd not found — install: brew install $cmd"
    fi
done

# Ollama
echo ""
echo "=== Ollama — Free Local LLM (no API key needed) ==="
if ! command -v ollama &>/dev/null; then
    echo "Ollama not installed. Install now? (y/n)"
    read -r ans
    if [ "$ans" = "y" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install ollama
        else
            curl -fsSL https://ollama.ai/install.sh | sh
        fi
    else
        echo "Skipped. Install later: brew install ollama"
        echo "Without Ollama, the pipeline uses rule-based timing (still works)."
    fi
fi

if command -v ollama &>/dev/null; then
    echo ""
    echo "Choose a model to pull:"
    echo "  1) mistral       (4 GB — best quality)"
    echo "  2) qwen2.5:3b    (2 GB — fastest on CPU)  ← recommended for testing"
    echo "  3) llama3.2:3b   (2 GB — good alternative)"
    echo "  4) Skip"
    read -r -p "Choice [1-4]: " choice
    case "$choice" in
        1) ollama pull mistral ;;
        2) ollama pull qwen2.5:3b
           sed -i '' 's/^OLLAMA_MODEL.*/OLLAMA_MODEL   = "qwen2.5:3b"/' \
               services/beat_analysis/flow_engine.py ;;
        3) ollama pull llama3.2:3b
           sed -i '' 's/^OLLAMA_MODEL.*/OLLAMA_MODEL   = "llama3.2:3b"/' \
               services/beat_analysis/flow_engine.py ;;
        *) echo "Skipped — pull later: ollama pull mistral" ;;
    esac
fi

echo ""
echo "=== Setup complete ==="
echo "Start Ollama : ollama serve          (separate terminal)"
echo "Start service: source venv/bin/activate && python main.py"
