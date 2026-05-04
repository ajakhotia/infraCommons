#!/usr/bin/env bash
set -euo pipefail

assume_yes=false
if [[ "${1:-}" == "-y" ]]; then
  assume_yes=true
fi

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (use sudo)." >&2
  exit 1
fi

require_confirmation() {
  if $assume_yes; then return 0; fi
  read -r -p "Proceed? [y/N]: " ans
  [[ "${ans,,}" == "y" || "${ans,,}" == "yes" ]]
}

# Detect OS
if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
else
  echo "Cannot detect OS (missing /etc/os-release). Aborting."
  exit 1
fi

echo "Detected: ID='${ID:-unknown}', VERSION_CODENAME='${VERSION_CODENAME:-unknown}'"

case "${ID:-}" in
  ubuntu)
    echo
    echo "Plan:"
    echo "  • Add the Ubuntu Toolchain PPA (ubuntu-toolchain-r/test) to access newer GCC/G++."
    echo "  • Update package lists."
    echo
    if ! require_confirmation; then
      echo "Aborted by user."
      exit 0
    fi
    if ! grep -qriE 'ubuntu-toolchain-r/test' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
      echo "Adding Ubuntu Toolchain PPA..."
      add-apt-repository -y -n ppa:ubuntu-toolchain-r/test
    else
      echo "Ubuntu Toolchain PPA already present. Skipping add."
    fi
    echo "Done. Run 'apt-get update' before installing GCC/G++ from this PPA."
    ;;

  debian)
    codename="${VERSION_CODENAME:-}"
    if [[ -z "$codename" ]]; then
      echo "Debian codename not found. Aborting."
      exit 1
    fi

    if [[ "$codename" == "sid" || "$codename" == "trixie" ]]; then
      echo
      echo "You're on Debian ${codename}. Backports are unnecessary here for newer GCC."
      echo "Nothing to do."
      exit 0
    fi

    suite="${codename}-backports"
    list_file="/etc/apt/sources.list.d/${suite}.list"
    keyring="/usr/share/keyrings/debian-archive-keyring.gpg"

    echo
    echo "Plan:"
    echo "  • Enable Debian backports (${suite}) to access newer GCC/G++ while staying on stable."
    echo "  • Update package lists."
    echo "Target file: ${list_file}"
    echo
    if ! require_confirmation; then
      echo "Aborted by user."
      exit 0
    fi
    if grep -qriE "(^|[[:space:]])${suite}([[:space:]]|$)" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null; then
      echo "${suite} repository already present. Skipping add."
    else
      echo "Adding ${suite} repository..."
      printf "deb [signed-by=%s] https://deb.debian.org/debian %s main\n" "$keyring" "$suite" > "$list_file"
      printf "deb-src [signed-by=%s] https://deb.debian.org/debian %s main\n" "$keyring" "$suite" >> "$list_file"
    fi
    echo "Done. Run 'apt-get update' before installing GCC/G++ from backports."
    ;;

  *)
    echo "Unsupported or unrecognized OS ID: '${ID:-}'. Aborting."
    exit 1
    ;;
esac
