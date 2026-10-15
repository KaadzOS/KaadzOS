#!/bin/sh
# Post-install hook for the ai pack: install Ollama, recommend a model size
# from detected hardware, and prepare whisper.cpp + Piper speech helpers.
set -eu

action=${1:-add}

recommend_model() {
  ram_mb=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo 2>/dev/null || echo 0)
  if [ "$ram_mb" -ge 16000 ]; then
    rec="llama3.1:8b (or larger, e.g. 70B on high-RAM hosts)"
  elif [ "$ram_mb" -ge 8000 ]; then
    rec="llama3.1:8b / qwen2.5:7b"
  elif [ "$ram_mb" -ge 4000 ]; then
    rec="phi3:mini / llama3.2:3b"
  else
    rec="llama3.2:1b (tiny build for low-RAM systems)"
  fi
  echo "kaadzos: ${ram_mb} MB RAM detected -> recommended Ollama model: $rec"
}

case $action in
  add)
    # Ollama's official installer (safe to re-run; it is idempotent).
    if ! command -v ollama >/dev/null 2>&1; then
      if command -v curl >/dev/null 2>&1; then
        curl -fsSL https://ollama.com/install.sh | sh || \
          echo "kaadzos: Ollama install failed; retry with: curl -fsSL https://ollama.com/install.sh | sh" >&2
      fi
    fi
    recommend_model

    # whisper.cpp speech-to-text (build from source when toolchain is present).
    if command -v git >/dev/null 2>&1 && command -v cmake >/dev/null 2>&1; then
      if [ ! -d /opt/whisper.cpp ]; then
        git clone --depth 1 https://github.com/ggml-org/whisper.cpp /opt/whisper.cpp || true
      fi
      if [ -d /opt/whisper.cpp ]; then
        make -C /opt/whisper.cpp -j"$(nproc 2>/dev/null || echo 2)" >/dev/null 2>&1 || \
          echo "kaadzos: whisper.cpp build failed; build it manually in /opt/whisper.cpp" >&2
      fi
    fi

    # Piper text-to-speech helper (official prebuilt release).
    if command -v curl >/dev/null 2>&1; then
      piper_dir=/opt/piper
      if [ ! -x "$piper_dir/piper" ]; then
        mkdir -p "$piper_dir"
        curl -fsSL https://github.com/rhasspy/piper/releases/latest/download/piper_linux_x86_64.tar.gz \
          -o "$piper_dir/piper.tar.gz" || true
        if [ -f "$piper_dir/piper.tar.gz" ]; then
          tar -xzf "$piper_dir/piper.tar.gz" -C "$piper_dir" --strip-components=1 2>/dev/null || true
          rm -f "$piper_dir/piper.tar.gz"
        fi
      fi
    fi
    ;;
  remove)
    rm -rf /opt/whisper.cpp /opt/piper
    if command -v ollama >/dev/null 2>&1; then
      systemctl stop ollama >/dev/null 2>&1 || true
      rm -f /usr/local/bin/ollama
    fi
    ;;
  *)
    echo "ai hook: unknown action '$action'" >&2
    exit 1
    ;;
esac
