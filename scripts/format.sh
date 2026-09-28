#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"
if [[ "${1:-}" == "--check" ]]; then
  swift format lint --strict --recursive Sources Tests Package.swift scripts/make-icon.swift
else
  swift format format --in-place --recursive Sources Tests Package.swift scripts/make-icon.swift
fi
