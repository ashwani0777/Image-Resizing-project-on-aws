#!/usr/bin/env bash
# Rebuilds layer/pillow-layer.zip for AWS Lambda (Python 3.12, x86_64).
# Works on Linux/macOS/WSL/Git-Bash. Needs Python 3 + pip + zip.
set -euo pipefail

cd "$(dirname "$0")/.."
rm -rf .layer-build && mkdir -p .layer-build/python

python3 -m pip install pillow \
  --platform manylinux2014_x86_64 --only-binary=:all: \
  --python-version 3.12 --implementation cp \
  --target .layer-build/python

find .layer-build -name '__pycache__' -prune -exec rm -rf {} +
find .layer-build -name '*.dist-info' -prune -exec rm -rf {} +

mkdir -p layer && rm -f layer/pillow-layer.zip
(cd .layer-build && zip -qr -9 ../layer/pillow-layer.zip python)
rm -rf .layer-build
echo "Built layer/pillow-layer.zip"
