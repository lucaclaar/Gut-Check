#!/bin/zsh
set -eu
project_root="$(cd "$(dirname "$0")/.." && pwd)"
checks_tmp="$(mktemp -d "${TMPDIR:-/tmp/}whynot-audio-checks.XXXXXX")"
trap 'rm -rf "$checks_tmp"' EXIT
xcrun swiftc -swift-version 6 -default-isolation MainActor \
  -module-cache-path "$checks_tmp/ModuleCache" \
  "$project_root/WhyNot/Services/AudioLevelAccumulator.swift" \
  "$project_root/WhyNot/Services/MicrophoneLevelMeter.swift" \
  "$project_root/WhyNot/Models/WaveformSample.swift" \
  "$project_root/WhyNot/Models/WaveformHistory.swift" \
  "$project_root/Checks/AudioWaveformChecks.swift" \
  -o "$checks_tmp/audio-checks"
"$checks_tmp/audio-checks"
