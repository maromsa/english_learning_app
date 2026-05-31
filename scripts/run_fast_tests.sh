#!/usr/bin/env bash
# Fast local gate: asset verification (unit) + map postMessage bridge (web integration).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CHROMEDRIVER_PORT="${CHROMEDRIVER_PORT:-4444}"
CHROMEDRIVER_CACHE="${ROOT}/.dart_tool/chromedriver"
CHROMEDRIVER_PID=""

cleanup() {
  if [[ -n "${CHROMEDRIVER_PID}" ]] && kill -0 "${CHROMEDRIVER_PID}" 2>/dev/null; then
    kill "${CHROMEDRIVER_PID}" 2>/dev/null || true
    wait "${CHROMEDRIVER_PID}" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

get_chrome_major() {
  local version=""
  if [[ "$(uname -s)" == "Darwin" ]] && [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
    version=$("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  elif command -v google-chrome >/dev/null 2>&1; then
    version=$(google-chrome --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  elif command -v chromium-browser >/dev/null 2>&1; then
    version=$(chromium-browser --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  fi
  if [[ -z "${version}" ]]; then
    fail "Could not detect Chrome version. Install Google Chrome or set CHROMEDRIVER_BIN."
  fi
  echo "${version%%.*}"
}

get_chromedriver_major() {
  local bin="$1"
  local version
  version=$("$bin" --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  echo "${version%%.*}"
}

find_cached_chromedriver() {
  local chrome_major="$1"
  local candidate=""
  while IFS= read -r candidate; do
    if [[ -x "${candidate}" ]]; then
      local driver_major
      driver_major=$(get_chromedriver_major "${candidate}" || true)
      if [[ "${driver_major}" == "${chrome_major}" ]]; then
        echo "${candidate}"
        return 0
      fi
    fi
  done < <(find "${CHROMEDRIVER_CACHE}" -type f -name chromedriver 2>/dev/null || true)
  return 1
}

read_chromedriver_major() {
  local bin="$1"
  local out_file
  out_file="$(mktemp)"
  "$bin" --version >"${out_file}" 2>/dev/null &
  local pid=$!
  local waited=0

  while kill -0 "${pid}" 2>/dev/null && [[ "${waited}" -lt 25 ]]; do
    sleep 0.2
    waited=$((waited + 1))
  done

  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    rm -f "${out_file}"
    return 1
  fi

  wait "${pid}" 2>/dev/null || true
  local version
  version=$(grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' "${out_file}" | head -1)
  rm -f "${out_file}"
  if [[ -z "${version}" ]]; then
    return 1
  fi
  echo "${version%%.*}"
}

ensure_chromedriver() {
  local chrome_major
  chrome_major="$(get_chrome_major)"

  local bin=""
  if [[ -n "${CHROMEDRIVER_BIN:-}" ]] && [[ -x "${CHROMEDRIVER_BIN}" ]]; then
    bin="${CHROMEDRIVER_BIN}"
  elif bin=$(find_cached_chromedriver "${chrome_major}" 2>/dev/null); then
    :
  elif command -v chromedriver >/dev/null 2>&1; then
    bin="$(command -v chromedriver)"
  fi

  if [[ -n "${bin}" ]]; then
    local driver_major=""
    driver_major=$(read_chromedriver_major "${bin}" 2>/dev/null || true)
    if [[ "${driver_major}" == "${chrome_major}" ]]; then
      if [[ "$(uname -s)" == "Darwin" ]]; then
        xattr -d com.apple.quarantine "${bin}" 2>/dev/null || true
      fi
      echo "${bin}"
      return 0
    fi
    if [[ -n "${driver_major}" ]]; then
      echo "==> chromedriver (${driver_major}) does not match Chrome (${chrome_major}); fetching matching build" >&2
    fi
  fi

  if ! command -v npx >/dev/null 2>&1; then
    fail "Node.js/npx required to download a matching chromedriver (Chrome ${chrome_major})."
  fi

  echo "==> Installing chromedriver@${chrome_major} via @puppeteer/browsers" >&2
  mkdir -p "${CHROMEDRIVER_CACHE}"
  local install_output
  if ! install_output=$(
    NODE_TLS_REJECT_UNAUTHORIZED="${NODE_TLS_REJECT_UNAUTHORIZED:-0}" \
      npx --yes @puppeteer/browsers install "chromedriver@${chrome_major}" \
        --path "${CHROMEDRIVER_CACHE}" 2>&1
  ); then
    echo "${install_output}" >&2
    fail "Failed to download chromedriver@${chrome_major}."
  fi

  bin=$(echo "${install_output}" | awk 'NF { last=$NF } END { print last }')
  if [[ ! -x "${bin}" ]]; then
    bin=$(find_cached_chromedriver "${chrome_major}" || true)
  fi
  if [[ -z "${bin}" ]] || [[ ! -x "${bin}" ]]; then
    fail "chromedriver install succeeded but executable was not found under ${CHROMEDRIVER_CACHE}."
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    xattr -d com.apple.quarantine "${bin}" 2>/dev/null || true
  fi

  echo "${bin}"
}

start_chromedriver() {
  local bin="$1"
  if curl -sf "http://127.0.0.1:${CHROMEDRIVER_PORT}/status" >/dev/null 2>&1; then
    if [[ -n "${CHROMEDRIVER_REUSE:-}" ]]; then
      echo "==> Reusing chromedriver already listening on port ${CHROMEDRIVER_PORT}"
      return 0
    fi
    echo "==> Stopping existing chromedriver on port ${CHROMEDRIVER_PORT}"
    lsof -ti "tcp:${CHROMEDRIVER_PORT}" | xargs kill 2>/dev/null || true
    sleep 1
  fi

  echo "==> Starting chromedriver on port ${CHROMEDRIVER_PORT}"
  "${bin}" --port="${CHROMEDRIVER_PORT}" >/tmp/chromedriver-fast-tests.log 2>&1 &
  CHROMEDRIVER_PID=$!

  for _ in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:${CHROMEDRIVER_PORT}/status" >/dev/null 2>&1; then
      return 0
    fi
    if ! kill -0 "${CHROMEDRIVER_PID}" 2>/dev/null; then
      cat /tmp/chromedriver-fast-tests.log >&2 || true
      fail "chromedriver exited before becoming ready on port ${CHROMEDRIVER_PORT}."
    fi
    sleep 0.5
  done

  cat /tmp/chromedriver-fast-tests.log >&2 || true
  fail "Timed out waiting for chromedriver on port ${CHROMEDRIVER_PORT}."
}

assert_drive_succeeded() {
  local output_file="$1"
  local drive_exit="$2"

  if grep -qE 'All tests skipped|Some tests failed|Test failed\.|Unable to start a WebDriver session|SessionNotCreatedException|EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK' "${output_file}"; then
    cat "${output_file}" >&2
    fail "Map integration test failed or was skipped (see output above)."
  fi

  if ! grep -qE 'All tests passed\.|All tests passed!' "${output_file}"; then
    cat "${output_file}" >&2
    fail "Map integration test did not report success (flutter drive exit ${drive_exit})."
  fi

  if [[ "${drive_exit}" -ne 0 ]]; then
    cat "${output_file}" >&2
    fail "flutter drive exited with code ${drive_exit}."
  fi
}

echo "==> Asset verification (flutter test)"
flutter test test/asset_verification_test.dart

echo "==> Map 3D postMessage bridge on Chrome (flutter drive + chromedriver)"
CHROMEDRIVER_BIN="$(ensure_chromedriver)"
start_chromedriver "${CHROMEDRIVER_BIN}"

DRIVE_LOG="$(mktemp)"
set +e
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/map_interaction_test.dart \
  -d chrome 2>&1 | tee "${DRIVE_LOG}"
DRIVE_EXIT="${PIPESTATUS[0]}"
set -e

assert_drive_succeeded "${DRIVE_LOG}" "${DRIVE_EXIT}"
rm -f "${DRIVE_LOG}"

echo "All fast tests passed."
