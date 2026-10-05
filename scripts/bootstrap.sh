#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=llama-version.env
source "${SCRIPT_DIR}/llama-version.env"

if [[ -z "${LLAMA_TAG:-}" || -z "${LLAMA_SHA256:-}" ]]; then
  echo "Error: LLAMA_TAG and LLAMA_SHA256 must be defined in llama-version.env" >&2
  exit 1
fi

VENDOR_DIR="${BASE_DIR}/Vendor"
mkdir -p "${VENDOR_DIR}"

ZIP_PATH="${VENDOR_DIR}/llama-${LLAMA_TAG}-xcframework.zip"
URL="https://github.com/ggml-org/llama.cpp/releases/download/${LLAMA_TAG}/llama-${LLAMA_TAG}-xcframework.zip"

echo "Downloading llama.xcframework (${LLAMA_TAG})..."
curl -sSL --fail "${URL}" -o "${ZIP_PATH}"

echo "Verifying checksum..."
if command -v sha256sum >/dev/null 2>&1; then
  ACTUAL_SHA=$(sha256sum "${ZIP_PATH}" | awk '{print $1}')
elif command -v shasum >/dev/null 2>&1; then
  ACTUAL_SHA=$(shasum -a 256 "${ZIP_PATH}" | awk '{print $1}')
else
  echo "Error: neither sha256sum nor shasum found" >&2
  exit 1
fi

if [[ "${ACTUAL_SHA}" != "${LLAMA_SHA256}" ]]; then
  echo "Error: Checksum mismatch for ${ZIP_PATH}!" >&2
  echo "Expected: ${LLAMA_SHA256}" >&2
  echo "Actual:   ${ACTUAL_SHA}" >&2
  rm -f "${ZIP_PATH}"
  exit 1
fi
echo "Checksum verified: ${ACTUAL_SHA}"

echo "Extracting llama.xcframework..."
rm -rf "${VENDOR_DIR}/llama.xcframework"

if command -v unzip >/dev/null 2>&1; then
  unzip -q -o "${ZIP_PATH}" -d "${VENDOR_DIR}"
elif command -v bsdtar >/dev/null 2>&1; then
  bsdtar -xf "${ZIP_PATH}" -C "${VENDOR_DIR}"
elif command -v python3 >/dev/null 2>&1; then
  python3 -c "import zipfile; zipfile.ZipFile('${ZIP_PATH}').extractall('${VENDOR_DIR}')"
else
  echo "Error: no extraction tool found (unzip, bsdtar, python3)" >&2
  exit 1
fi

# Clean zip
rm -f "${ZIP_PATH}"

if [[ ! -d "${VENDOR_DIR}/llama.xcframework" ]]; then
  CANDIDATE=$(find "${VENDOR_DIR}" -maxdepth 2 -type d -name "*llama*.xcframework" | head -n 1)
  if [[ -n "${CANDIDATE}" && "${CANDIDATE}" != "${VENDOR_DIR}/llama.xcframework" ]]; then
    mv "${CANDIDATE}" "${VENDOR_DIR}/llama.xcframework"
  fi
fi

if [[ ! -d "${VENDOR_DIR}/llama.xcframework" ]]; then
  echo "Error: Vendor/llama.xcframework was not found after extraction" >&2
  exit 1
fi

# Ensure iOS simulator slice exists for testing
python3 -c "
import shutil, plistlib, struct
from pathlib import Path

xcfw = Path('${VENDOR_DIR}/llama.xcframework')
ios_arm64 = xcfw / 'ios-arm64'
ios_sim = xcfw / 'ios-arm64-simulator'

if not ios_sim.exists() and ios_arm64.exists():
    shutil.copytree(ios_arm64, ios_sim)
    dylib = ios_sim / 'llama.framework' / 'llama'
    with open(dylib, 'r+b') as f:
        magic, cputype, cpusubtype, filetype, ncmds, sizeofcmds, flags, reserved = struct.unpack('<IIIIIIII', f.read(32))
        for _ in range(ncmds):
            offset = f.tell()
            cmd, cmdsize = struct.unpack('<II', f.read(8))
            if cmd == 0x32: # LC_BUILD_VERSION
                platform = struct.unpack('<I', f.read(4))[0]
                if platform == 2:
                    f.seek(offset + 8)
                    f.write(struct.pack('<I', 7)) # 7 = iOS Simulator
                break
            else:
                f.seek(offset + cmdsize)

    plist_path = xcfw / 'Info.plist'
    with open(plist_path, 'rb') as f:
        pl = plistlib.load(f)
    sim_entry = {
        'BinaryPath': 'llama.framework/llama',
        'LibraryIdentifier': 'ios-arm64-simulator',
        'LibraryPath': 'llama.framework',
        'SupportedArchitectures': ['arm64'],
        'SupportedPlatform': 'ios',
        'SupportedPlatformVariant': 'simulator'
    }
    if not any(lib.get('LibraryIdentifier') == 'ios-arm64-simulator' for lib in pl.get('AvailableLibraries', [])):
        pl['AvailableLibraries'].append(sim_entry)
        with open(plist_path, 'wb') as f:
            plistlib.dump(pl, f)
"

echo "Stripping code signatures from XCFramework..."
find "${VENDOR_DIR}/llama.xcframework" -name "_CodeSignature" -type d -exec rm -rf {} + 2>/dev/null || true
if command -v codesign >/dev/null 2>&1; then
  find "${VENDOR_DIR}/llama.xcframework" -type f \( -name "llama" -o -name "*.dylib" \) -exec codesign --remove-signature {} + 2>/dev/null || true
fi

echo "Successfully bootstrapped llama.xcframework into ${VENDOR_DIR}/llama.xcframework"
