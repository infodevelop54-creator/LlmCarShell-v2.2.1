#!/usr/bin/env bash
set -euo pipefail

# ─── Абсолютные пути ────────────────────────────────────────────────
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LLAMA_DIR="$ROOT_DIR/third_party/llama.cpp"
BUILD_DIR="$LLAMA_DIR/build-android"
ASSETS_DIR="$ROOT_DIR/app/src/main/assets"

echo "ROOT_DIR=$ROOT_DIR"
echo "LLAMA_DIR=$LLAMA_DIR"

# ─── ПИН на рабочий тег ─────────────────────────────────────────────
# b5096 — проверен: tools/server/ с полноценной CMake-обвязкой
# Для более старых тегов (b4xxx) используйте examples/server/ + LLAMA_BUILD_EXAMPLES=ON
LLAMA_TAG="b4400"
LLAMA_REPO="https://github.com/ggerganov/llama.cpp"

# ─── NDK ────────────────────────────────────────────────────────────
NDK_ROOT="${ANDROID_NDK_ROOT:-${ANDROID_NDK_HOME:-${ANDROID_NDK:-}}}"
if [ -z "$NDK_ROOT" ] || [ ! -d "$NDK_ROOT" ]; then
  echo "::error::NDK не найден (ANDROID_NDK_ROOT)"; exit 1
fi
echo "NDK: $NDK_ROOT"

# ─── Переклонирование при смене тега в кэше ─────────────────────────
if [ -d "$LLAMA_DIR/.git" ]; then
  CURRENT_TAG=$(git -C "$LLAMA_DIR" describe --tags --exact-match 2>/dev/null || echo "unknown")
  if [ "$CURRENT_TAG" != "$LLAMA_TAG" ]; then
    echo "Кэш содержит $CURRENT_TAG, ожидался $LLAMA_TAG — переклонирование"
    rm -rf "$LLAMA_DIR"
  fi
fi

if [ ! -d "$LLAMA_DIR/.git" ]; then
  mkdir -p "$ROOT_DIR/third_party"
  echo "Клонирование llama.cpp@${LLAMA_TAG}..."
  git clone --depth 1 --branch "$LLAMA_TAG" "$LLAMA_REPO" "$LLAMA_DIR"
fi

# ─── Патч std::setlocale (страховка) ────────────────────────────────
if grep -rl 'std::setlocale' "$LLAMA_DIR/tools" "$LLAMA_DIR/examples" 2>/dev/null | grep -q .; then
  echo "Патч std::setlocale..."
  grep -rl 'std::setlocale' "$LLAMA_DIR/tools" "$LLAMA_DIR/examples" 2>/dev/null | while read -r f; do
    sed -i 's/std::setlocale/setlocale/g' "$f"
  done
fi

# ─── Конфигурация ───────────────────────────────────────────────────
cmake -S "$LLAMA_DIR" -B "$BUILD_DIR" \
  -DCMAKE_TOOLCHAIN_FILE="$NDK_ROOT/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=android-28 \
  -DLLAMA_BUILD_SERVER=ON \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=ON \
  -DLLAMA_CURL=OFF \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_BUILD_TYPE=Release

# ─── Явный --target llama-server с фоллбэком на 'all' ───────────────
echo "Building target llama-server..."
if cmake --build "$BUILD_DIR" --config Release -j"$(nproc)" --target llama-server; then
  echo "✓ llama-server target собран"
else
  echo "::warning::target llama-server не найден, собираем 'all'"
  cmake --build "$BUILD_DIR" --config Release -j"$(nproc)"
fi

# ─── Диагностика ────────────────────────────────────────────────────
echo "=== Содержимое build/bin ==="
ls -la "$BUILD_DIR/bin/" 2>/dev/null || echo "(нет bin/)"
echo "=== Поиск llama-server по всему дереву ==="
find "$BUILD_DIR" -name "llama-server*" -type f 2>/dev/null || echo "(не найден)"
echo "=== Все исполняемые файлы llama-* ==="
find "$BUILD_DIR" -name "llama-*" -type f -executable 2>/dev/null | head -20 || true

# ─── Копирование в assets ───────────────────────────────────────────
mkdir -p "$ASSETS_DIR"
SERVER_PATH=$(find "$BUILD_DIR" -name "llama-server" -type f | head -n1)
if [ -z "$SERVER_PATH" ]; then
  echo "::error::llama-server не найден после сборки."
  echo "Тег $LLAMA_TAG не имеет рабочего таргета llama-server."
  echo "Попробуйте: LLAMA_TAG=b4400 (старый) или LLAMA_TAG=b5096 (новый)."
  exit 1
fi

cp "$SERVER_PATH" "$ASSETS_DIR/llama-server"
chmod +x "$ASSETS_DIR/llama-server"
find "$BUILD_DIR" -name "*.so" -exec cp {} "$ASSETS_DIR/" \;

echo "✓ Assets готовы:"
ls -la "$ASSETS_DIR/"
