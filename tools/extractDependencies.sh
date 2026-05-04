#!/bin/sh
# Resolve a dependency entry from systemDependencies.json for the current OS.
# Exact key match only: "<os_id>:<version>"
# - Linux:  os_id = ID from /etc/os-release, version = VERSION_ID
# - macOS:  os_id = macos, version = $(sw_vers -productVersion) (e.g., 14.5.1)
set -eu

# ---------- Exit code constants (from sysexits.h) ----------
EX_OK=0           # successful termination
EX_USAGE=64       # command line usage error
EX_DATAERR=65     # invalid input data
EX_NOINPUT=66     # cannot open input
EX_UNAVAILABLE=69 # service unavailable (e.g. unsupported OS)
EX_SOFTWARE=70    # internal software error
EX_OSERR=71       # system error
EX_CANTCREAT=73   # can't create (file/dir)
EX_NOPERM=77      # permission denied
EX_CONFIG=78      # configuration error

print_usage() {
  printf '%s\n' \
    "Usage: sh extractDependencies.sh [--expand \"VAR1 VAR2 ...\"] <GROUP NAMES> <PATH TO systemDependencies.json>" \
    "" \
    "Arguments:" \
    "  <GROUP NAMES>                       One or more whitespace-separated group names to query." \
    "  <PATH TO systemDependencies.json>   Path to the JSON file containing dependency definitions." \
    "" \
    "Options:" \
    "  --expand \"VAR1 VAR2 ...\"            Whitespace-separated allow-list of environment variables" \
    "                                      to substitute in resolved dependency strings. Only listed" \
    "                                      variables are expanded; other \$ patterns pass through" \
    "                                      verbatim. Each listed variable must be set and non-empty" \
    "                                      or the script aborts. Requires 'envsubst' ('gettext-base'" \
    "                                      on Debian/Ubuntu, 'brew install gettext' on macOS)." \
    "" \
    "The script detects your OS and version, then looks up an exact key match" \
    "in the JSON (format: '<os_id>:<version>') for each group and emits their" \
    "dependency strings joined by a single space." \
    "" \
    "Refer to the \"groups\" array in the JSON file to see valid group names" \
    "and the OS keys available for each group." \
    "" \
    "Examples:" \
    "  sh extractDependencies.sh Basics ./systemDependencies.json" \
    "  sh extractDependencies.sh \"Basics Compilers\" ./systemDependencies.json" \
    "  sh extractDependencies.sh --expand \"ROS_DISTRO\" \"Basics RosDeps\" ./systemDependencies.json" >&2
}

fail() {
  code="${1}"
  shift
  printf 'Error: %s\n' "$*" >&2
  exit "${code}"
}

require_jq() {
  command -v jq > /dev/null 2>&1 || fail 127 "jq is required but not installed or not in PATH."
}

require_envsubst() {
  command -v envsubst > /dev/null 2>&1 || fail 127 "envsubst is required for --expand but not installed (install 'gettext-base' on Debian/Ubuntu, or 'brew install gettext' on macOS)."
}

require_readable_file() {
  path="${1}"
  [ -r "${path}" ] || fail ${EX_NOINPUT} "cannot read file: ${path}"
}

# Detect OS into OS_ID and OS_VERSION (exact values used for key)
detect_os() {
  uname_s="$(uname -s 2> /dev/null || echo unknown)"
  case "${uname_s}" in
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-linux}"
        OS_VERSION="${VERSION_ID:-}"
        [ -n "${OS_VERSION}" ] || fail ${EX_SOFTWARE} "/etc/os-release missing VERSION_ID."
      else
        fail ${EX_UNAVAILABLE} "/etc/os-release not found; cannot detect Linux distribution."
      fi
      ;;
    Darwin)
      OS_ID="macos"
      if command -v sw_vers > /dev/null 2>&1; then
        OS_VERSION="$(sw_vers -productVersion | tr -d '\r')"
      else
        fail ${EX_UNAVAILABLE} "sw_vers not available; cannot detect macOS version."
      fi
      [ -n "${OS_VERSION}" ] || fail ${EX_SOFTWARE} "could not determine macOS version."
      ;;
    *)
      fail ${EX_UNAVAILABLE} "unsupported operating system: ${uname_s}"
      ;;
  esac
}

# Resolve the dependency string for a single group on stdout. Unknown groups are
# skipped with a warning (empty stdout); groups present in the JSON but missing
# an entry for the current OS key are a hard error.
resolve_group() {
  group="${1}"

  if ! jq -e --arg GRP "${group}" '.groups[] | select(.group == $GRP)' "${DEPENDENCIES_JSON_PATH}" > /dev/null; then
    printf 'No system dependencies specified for "%s".\n' "${group}" >&2
    return 0
  fi

  value="$(jq -r \
    --arg GRP "${group}" \
    --arg KEY "${OS_KEY}" \
    '.groups[] | select(.group == $GRP) | .[$KEY] // empty' \
    "${DEPENDENCIES_JSON_PATH}")"

  if [ -z "${value}" ] || [ "${value}" = "null" ]; then
    printf 'Error: no exact entry for key "%s" in group "%s".\n' "${OS_KEY}" "${group}" >&2
    printf 'Known keys for this group:\n' >&2
    jq -r --arg GRP "${group}" '.groups[] | select(.group == $GRP) | keys[]' "${DEPENDENCIES_JSON_PATH}" >&2
    exit ${EX_DATAERR}
  fi

  printf '%s' "${value}"
}

# ---------- Main ----------

# Parse leading options. Stops at first non-option positional, '--', or end of args.
EXPAND_VARS=""
while [ $# -gt 0 ]; do
  case "${1}" in
    --expand)
      [ $# -ge 2 ] || { print_usage; fail ${EX_USAGE} "--expand requires an argument."; }
      EXPAND_VARS="${2}"
      shift 2
      ;;
    --expand=*)
      EXPAND_VARS="${1#--expand=}"
      shift
      ;;
    --)
      shift
      break
      ;;
    -*)
      print_usage
      fail ${EX_USAGE} "unknown option: ${1}"
      ;;
    *)
      break
      ;;
  esac
done

GROUP_NAMES="${1:-}"
DEPENDENCIES_JSON_PATH="${2:-}"

if [ -z "${GROUP_NAMES}" ] || [ -z "${DEPENDENCIES_JSON_PATH}" ]; then
  print_usage
  exit ${EX_USAGE}
fi

require_jq
require_readable_file "${DEPENDENCIES_JSON_PATH}"
detect_os

# Validate every --expand variable is set and non-empty, and build envsubst's
# allow-list shell-format string ('${VAR1} ${VAR2} ...'). envsubst only
# substitutes variables whose references appear in this string; other '$'
# patterns in the JSON pass through verbatim.
ALLOW_LIST=""
if [ -n "${EXPAND_VARS}" ]; then
  require_envsubst
  # shellcheck disable=SC2086
  for var in ${EXPAND_VARS}; do
    eval "value=\${${var}:-}"
    [ -n "${value}" ] || fail ${EX_CONFIG} "--expand variable '${var}' is unset or empty in environment."
    if [ -z "${ALLOW_LIST}" ]; then
      ALLOW_LIST="\${${var}}"
    else
      ALLOW_LIST="${ALLOW_LIST} \${${var}}"
    fi
  done
fi

OS_KEY="${OS_ID}:${OS_VERSION}"

# Iterate over whitespace-separated group names and print each group's deps
# joined by a single space. Unquoted expansion is intentional — we rely on the
# shell word-splitting GROUP_NAMES into individual group tokens.
OUTPUT=""
# shellcheck disable=SC2086
for group in ${GROUP_NAMES}; do
  value="$(resolve_group "${group}")"
  if [ -n "${value}" ]; then
    if [ -z "${OUTPUT}" ]; then
      OUTPUT="${value}"
    else
      OUTPUT="${OUTPUT} ${value}"
    fi
  fi
done

if [ -n "${ALLOW_LIST}" ]; then
  printf '%s' "${OUTPUT}" | envsubst "${ALLOW_LIST}"
else
  printf '%s' "${OUTPUT}"
fi
