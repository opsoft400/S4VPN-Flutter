#!/usr/bin/env bash
# Build every engine core the app can drive, for each Android ABI, and stage
# them as `lib<name>.so` in the app's jniLibs tree.
#
# A core ships under a shared-object name because that is the only thing
# Android leaves in a directory the app may exec from; the app's CoreExtractor
# copies the one it needs somewhere writable and marks it executable.
#
# Every core is built on its own and every failure is reported rather than
# fatal: an APK without one core still installs, and the app says plainly which
# core is missing when that mode is picked. A build that dies on the first
# missing toolchain produces no APK at all, which is worse.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINES="$ROOT/native/engines"
WORK="${CI_WORK:-$ROOT/.work/cores}"
JNI="$ROOT/android/app/src/main/jniLibs"
ABIS=("arm64-v8a" "armeabi-v7a" "x86_64")

# Android ABI -> Rust target triple, and the GOARCH a Go build wants.
rust_triple() {
  case "$1" in
    arm64-v8a) echo "aarch64-linux-android" ;;
    armeabi-v7a) echo "armv7-linux-androideabi" ;;
    x86_64) echo "x86_64-linux-android" ;;
  esac
}
goarch() {
  case "$1" in
    arm64-v8a) echo "arm64" ;;
    armeabi-v7a) echo "arm" ;;
    x86_64) echo "amd64" ;;
  esac
}

mkdir -p "$WORK" "$JNI"
log() { echo "::group::$*"; echo "-> $*"; }
logdone() { echo "::endgroup::"; }
ok() { echo "core ready: $1"; }
fail() { echo "core MISSING: $1 -- $2"; }

stage() {
  # stage <core> <abi> <source-file>
  local core="$1" abi="$2" src="$3"
  if [[ ! -f "$src" ]]; then
    fail "$core/$abi" "no such file: $src"
    return 1
  fi
  mkdir -p "$JNI/$abi"
  cp -f "$src" "$JNI/$abi/lib$core.so"
  chmod 0644 "$JNI/$abi/lib$core.so"
  ok "$core/$abi"
  return 0
}

# ---------------------------------------------------------------- DNS engines
# StormDNS and CottenDns ship ready-made in the WhiteDNS release: they are
# executables that happen to be named like shared objects, one per ABI.
build_dns() {
  log "DNS cores (StormDNS / CottenDns) from WhiteDNS"
  local zip
  zip="$(ls "$ENGINES"/WhiteDNS-Android-*.zip 2>/dev/null | head -1)"
  if [[ -z "$zip" ]]; then
    fail "stormdns" "WhiteDNS-Android-*.zip not found in native/engines"
    return
  fi
  local dir="$WORK/whitedns"
  rm -rf "$dir"
  mkdir -p "$dir"
  unzip -o -q "$zip" -d "$dir" || {
    fail "stormdns" "could not unpack $zip"
    return
  }
  local abi
  for abi in "${ABIS[@]}"; do
    local storm cotten
    storm="$(find "$dir" -path "*jniLibs/$abi/libstormdns_client.so" -type f | head -1)"
    cotten="$(find "$dir" -path "*jniLibs/$abi/libcottendns_client.so" -type f | head -1)"
    [[ -n "$storm" ]] && stage stormdns "$abi" "$storm"
    [[ -n "$cotten" ]] && stage cottendns "$abi" "$cotten"
  done
  logdone
}

# --------------------------------------------------------------------- Aether
# Aether 2.3.0 is Rust. The sources are inside the WhiteAestherMobile release,
# and cargo-ndk cross-compiles them for the three ABIs at once.
build_aether() {
  log "Aether core (Rust) from WhiteAestherMobile"
  local zip
  zip="$(ls "$ENGINES"/WhiteAestherMobile-*.zip 2>/dev/null | head -1)"
  if [[ -z "$zip" ]]; then
    fail "aether" "WhiteAestherMobile-*.zip not found in native/engines"
    return
  fi
  local dir="$WORK/aether"
  rm -rf "$dir"
  mkdir -p "$dir"
  unzip -o -q "$zip" -d "$dir" || {
    fail "aether" "could not unpack $zip"
    return
  }
  local manifest
  manifest="$(find "$dir" -path '*/native/aether/aether/Cargo.toml' -type f | head -1)"
  if [[ -z "$manifest" ]]; then
    fail "aether" "Cargo.toml not found in the release"
    return
  fi
  local crate
  crate="$(dirname "$manifest")"
  if ! command -v cargo >/dev/null; then
    fail "aether" "cargo is not installed"
    return
  fi
  if ! cargo ndk --version >/dev/null 2>&1; then
    fail "aether" "cargo-ndk is not installed"
    return
  fi
  local out="$WORK/aether-out"
  rm -rf "$out"
  if ! (cd "$crate" && cargo ndk --platform 26 \
        -t aarch64-linux-android -t armv7-linux-androideabi -t x86_64-linux-android \
        -o "$out" build --release --locked --bin aether 2>&1 | tail -25); then
    fail "aether" "cargo ndk build failed"
    return
  fi
  local abi
  for abi in "${ABIS[@]}"; do
    local triple
    triple="$(rust_triple "$abi")"
    local src
    src="$(find "$out" -path "*$triple*/release/aether" -type f | head -1)"
    [[ -n "$src" ]] && stage aether "$abi" "$src"
  done
  logdone
}

# -------------------------------------------------------------------- Lantern
# Lantern is Go. Its own release ships the core as a Go module, and the same
# source cross-compiles for Android as a plain executable.
build_lantern() {
  log "Lantern core (Go) from the Lantern release"
  local zip
  zip="$(ls "$ENGINES"/v10.0.0-lant.zip 2>/dev/null | head -1)"
  if [[ -z "$zip" ]]; then
    fail "lantern" "v10.0.0-lant.zip not found in native/engines"
    return
  fi
  local dir="$WORK/lantern"
  rm -rf "$dir"
  mkdir -p "$dir"
  unzip -o -q "$zip" -d "$dir" || {
    fail "lantern" "could not unpack $zip"
    return
  }
  local src_root
  src_root="$(find "$dir" -maxdepth 1 -type d -name 'lantern-*' | head -1)"
  if [[ -z "$src_root" ]]; then
    fail "lantern" "the Lantern source tree was not found"
    return
  fi
  if ! command -v go >/dev/null; then
    fail "lantern" "go is not installed"
    return
  fi
  local abi
  for abi in "${ABIS[@]}"; do
    local arch
    arch="$(goarch "$abi")"
    local out="$WORK/lantern-out/$abi/lantern"
    mkdir -p "$(dirname "$out")"
    if ! (cd "$src_root" && CGO_ENABLED=0 GOOS=android GOARCH="$arch" \
          go build -o "$out" -ldflags "-s -w" ./lantern-core 2>&1 | tail -10); then
      fail "lantern/$abi" "go build failed"
      continue
    fi
    stage lantern "$abi" "$out"
  done
  logdone
}

# -------------------------------------------------------------------- Psiphon
# psiphon-tunnel-core is Go, and its release publishes libraries rather than
# executables, so the core is built from its own source.
build_psiphon() {
  log "Psiphon core (Go) from psiphon-tunnel-core"
  if ! command -v go >/dev/null; then
    fail "psiphon" "go is not installed"
    return
  fi
  local src="$WORK/psiphon-tunnel-core"
  if [[ ! -d "$src" ]]; then
    git clone --depth 1 https://github.com/Psiphon-Labs/psiphon-tunnel-core.git "$src" || {
      fail "psiphon" "could not clone psiphon-tunnel-core"
      return
    }
  fi
  local abi
  for abi in "${ABIS[@]}"; do
    local arch
    arch="$(goarch "$abi")"
    local out="$WORK/psiphon-out/$abi/psiphon-tunnel-core"
    mkdir -p "$(dirname "$out")"
    if ! (cd "$src" && CGO_ENABLED=0 GOOS=android GOARCH="$arch" \
          go build -o "$out" -ldflags "-s -w" ./cmd/psiphon-tunnel 2>&1 | tail -10); then
      fail "psiphon/$abi" "go build failed"
      continue
    fi
    stage psiphon "$abi" "$out"
  done
  logdone
}

# --------------------------------------------------------------------- Mihomo
# Mihomo is the White engine's core: Go, built from the Clash.Meta tree the
# WhiteVPN release is built from.
build_mihomo() {
  log "Mihomo core (Go) from Clash.Meta"
  if ! command -v go >/dev/null; then
    fail "mihomo" "go is not installed"
    return
  fi
  local src="$WORK/Clash.Meta"
  if [[ ! -d "$src" ]]; then
    git clone --depth 1 https://github.com/chen08209/Clash.Meta.git "$src" || {
      fail "mihomo" "could not clone Clash.Meta"
      return
    }
  fi
  local abi
  for abi in "${ABIS[@]}"; do
    local arch
    arch="$(goarch "$abi")"
    local out="$WORK/mihomo-out/$abi/mihomo"
    mkdir -p "$(dirname "$out")"
    if ! (cd "$src" && CGO_ENABLED=0 GOOS=android GOARCH="$arch" \
          go build -o "$out" -ldflags "-s -w" ./ 2>&1 | tail -15); then
      fail "mihomo/$abi" "go build failed"
      continue
    fi
    stage mihomo "$abi" "$out"
  done
  logdone
}

build_dns
build_aether
build_lantern
build_psiphon
build_mihomo

log "staged cores"
for abi in "${ABIS[@]}"; do
  echo "== $abi"
  ls -la "$JNI/$abi" 2>/dev/null | tail -n +2 || true
done
logdone
