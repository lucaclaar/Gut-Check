#!/bin/zsh
set -eu
project_root="$(cd "$(dirname "$0")/.." && pwd)"
checks_tmp="$(mktemp -d "${TMPDIR:-/tmp/}whynot-checks.XXXXXX")"
trap 'rm -rf "$checks_tmp"' EXIT
xcrun swiftc -swift-version 6 -default-isolation MainActor \
  -module-cache-path "$checks_tmp/ModuleCache" \
  "$project_root"/WhyNot/Models/*.swift \
  "$project_root/WhyNot/DesignSystem/GutTheme.swift" \
  "$project_root/Checks/ReflectionChecks.swift" \
  "$project_root/Checks/ReflectionGenerationChecks.swift" \
  "$project_root/Checks/SafetyChecks.swift" \
  "$project_root/Checks/TurboChecks.swift" \
  -o "$checks_tmp/reflection-checks"
"$checks_tmp/reflection-checks" "$project_root/WhyNot/Resources/SafetyContacts.json"
