#!/bin/bash
set -e

ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$ROOT/logs"
mkdir -p "$LOG_DIR"

G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; R='\033[0;31m'; N='\033[0m'

echo ""
echo -e "${C}╔══════════════════════════════════════════╗${N}"
echo -e "${C}║       AUREON — 100% FREE AI STACK        ║${N}"
echo -e "${C}╚══════════════════════════════════════════╝${N}"
echo ""

# ── 0. Ollama (free local LLM) ────────────────────────────────────────────────
echo -e "${G}[0/3] Ollama (free local LLM)...${N}"
OLLAMA_PID=""
if command -v ollama &>/dev/null; then
    if curl -s http://localhost:11434/api/tags &>/dev/null; then
        echo -e "  ${G}✓ Ollama already running on :11434${N}"
    else
        echo -e "  ${Y}→ Starting Ollama server...${N}"
        ollama serve > "$LOG_DIR/ollama.log" 2>&1 &
        OLLAMA_PID=$!
        sleep 2
        echo -e "  ${G}✓ Ollama started (PID $OLLAMA_PID)${N}"
    fi
    MODELS=$(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}' | tr '\n' ' ')
    if [ -n "$MODELS" ]; then
        echo -e "  ${C}  Available models: $MODELS${N}"
    else
        echo -e "  ${Y}  ⚠ No models pulled yet — pipeline uses math fallback${N}"
        echo -e "  ${Y}    Fix: ollama pull mistral${N}"
    fi
else
    echo -e "  ${Y}⚠ Ollama not installed — pipeline uses rule-based timing fallback${N}"
    echo -e "  ${Y}  Install: brew install ollama && ollama pull mistral${N}"
fi

# ── 1. Python audio service ───────────────────────────────────────────────────
echo ""
echo -e "${G}[1/3] Python audio service...${N}"
PYTHON_VENV="$ROOT/python_audio_service/venv"
if [ ! -d "$PYTHON_VENV" ]; then
    echo -e "${Y}  → First run: creating venv and installing deps...${N}"
    cd "$ROOT/python_audio_service"
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt --quiet
fi
source "$PYTHON_VENV/bin/activate"
cd "$ROOT/python_audio_service"
uvicorn main:app --host 0.0.0.0 --port 8000 --reload \
    > "$LOG_DIR/python.log" 2>&1 &
PYTHON_PID=$!
echo -e "  ${G}✓ Python service → http://localhost:8000  (PID $PYTHON_PID)${N}"
echo -e "  ${C}  API docs → http://localhost:8000/docs${N}"

# ── 2. .NET backend ───────────────────────────────────────────────────────────
echo ""
echo -e "${G}[2/3] .NET backend...${N}"
cd "$ROOT/dotnet_backend"
dotnet run --project AureonApi/AureonApi.csproj \
    > "$LOG_DIR/dotnet.log" 2>&1 &
DOTNET_PID=$!
echo -e "  ${G}✓ .NET API → http://localhost:5000  (PID $DOTNET_PID)${N}"
echo -e "  ${C}  Swagger  → http://localhost:5000/swagger${N}"

# ── 3. Flutter ────────────────────────────────────────────────────────────────
FLUTTER_PID=""
if [[ "$1" != "--no-flutter" ]]; then
    echo ""
    echo -e "${G}[3/3] Flutter app...${N}"
    cd "$ROOT/flutter_app/aureon"
    flutter run > "$LOG_DIR/flutter.log" 2>&1 &
    FLUTTER_PID=$!
    echo -e "  ${G}✓ Flutter started (PID $FLUTTER_PID)${N}"
else
    echo ""
    echo -e "${Y}[3/3] Flutter skipped (--no-flutter)${N}"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${C}══════════════════════════════════════════════${N}"
echo -e "${G}  All services running — zero paid APIs${N}"
echo ""
echo -e "  Ollama  (AI)    →  http://localhost:11434"
echo -e "  Python  (Audio) →  http://localhost:8000"
echo -e "  .NET    (API)   →  http://localhost:5000"
echo -e "  Swagger         →  http://localhost:5000/swagger"
echo ""
echo -e "${Y}  No API keys. No cloud. No cost.${N}"
echo -e "${C}══════════════════════════════════════════════${N}"
echo -e "${Y}Press Ctrl+C to stop all services.${N}"

# ── Cleanup ───────────────────────────────────────────────────────────────────
cleanup() {
    echo ""
    echo -e "${R}Shutting down...${N}"
    [ -n "$OLLAMA_PID" ]  && kill "$OLLAMA_PID"  2>/dev/null && echo "  stopped Ollama"
    [ -n "$PYTHON_PID" ]  && kill "$PYTHON_PID"  2>/dev/null && echo "  stopped Python"
    [ -n "$DOTNET_PID" ]  && kill "$DOTNET_PID"  2>/dev/null && echo "  stopped .NET"
    [ -n "$FLUTTER_PID" ] && kill "$FLUTTER_PID" 2>/dev/null && echo "  stopped Flutter"
    echo -e "${G}Done.${N}"
}
trap cleanup EXIT INT TERM
wait
