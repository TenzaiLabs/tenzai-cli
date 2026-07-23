#!/bin/sh
set -eu

repo="TenzaiLabs/tenzai-cli"
releases_url="https://github.com/$repo/releases"
partial=""

fail() {
    printf 'tenzai installer: %s\n' "$*" >&2
    exit 1
}

command -v curl >/dev/null 2>&1 || fail "curl is required"
command -v tar >/dev/null 2>&1 || fail "tar is required"

dir_is_writable() {
    candidate="$1"
    mkdir -p "$candidate" 2>/dev/null || return 1
    probe="$candidate/.tenzai-install-probe.$$"
    (umask 077 && : > "$probe") 2>/dev/null || return 1
    rm -f "$probe"
}

default_install_dir() {
    if [ -n "${HOME:-}" ] && dir_is_writable "$HOME/.local/bin"; then
        printf '%s\n' "$HOME/.local/bin"
        return
    fi

    if command -v brew >/dev/null 2>&1; then
        brew_prefix="$(brew --prefix 2>/dev/null || true)"
        if [ -n "$brew_prefix" ] && dir_is_writable "$brew_prefix/bin"; then
            printf '%s\n' "$brew_prefix/bin"
            return
        fi
    fi

    if dir_is_writable "/usr/local/bin"; then
        printf '%s\n' "/usr/local/bin"
        return
    fi

    fail "no writable install directory found; set TENZAI_INSTALL_DIR"
}

os="$(uname -s)"
arch="$(uname -m)"

case "$os" in
    Linux)
        case "$arch" in
            x86_64) target="x86_64-unknown-linux-gnu" ;;
            aarch64 | arm64) target="aarch64-unknown-linux-gnu" ;;
            *) fail "unsupported Linux architecture: $arch" ;;
        esac
        ;;
    Darwin)
        case "$arch" in
            x86_64) target="x86_64-apple-darwin" ;;
            arm64 | aarch64) target="aarch64-apple-darwin" ;;
            *) fail "unsupported macOS architecture: $arch" ;;
        esac
        ;;
    MINGW* | MSYS* | CYGWIN*)
        fail "Windows installation is not supported by this script. Download Tenzai CLI manually from $releases_url/latest"
        ;;
    *) fail "unsupported operating system: $os" ;;
esac

printf 'Finding the latest Tenzai CLI release...\n'
tag="$(
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
        grep '"tag_name"' |
        sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
)"
[ -n "$tag" ] || fail "could not determine the latest release"

case "$tag" in
    tenzai-v[0-9]* ) ;;
    *) fail "latest release has an unexpected tag: $tag" ;;
esac

version="${tag#tenzai-v}"
case "$version" in
    *[!0-9A-Za-z.-]* | *..* | .* | *.) fail "latest release has an invalid version: $version" ;;
esac

archive="tenzai-$version-$target.tar.gz"
download_url="$releases_url/download/$tag/$archive"
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/tenzai-install.XXXXXX")" || fail "could not create a temporary directory"

cleanup() {
    if [ -n "$partial" ]; then
        rm -f "$partial"
    fi
    rm -rf "$tmp_dir"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

printf 'Downloading Tenzai CLI %s for %s...\n' "$version" "$target"
curl -fsSL "$download_url" -o "$tmp_dir/$archive"
curl -fsSL "$download_url.sha256" -o "$tmp_dir/$archive.sha256"

expected="$(sed -n '1s/[[:space:]].*//p' "$tmp_dir/$archive.sha256")"
[ -n "$expected" ] || fail "release checksum is empty"

if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$tmp_dir/$archive" | sed 's/[[:space:]].*//')"
elif command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "$tmp_dir/$archive" | sed 's/[[:space:]].*//')"
else
    fail "sha256sum or shasum is required to verify the download"
fi

[ "$actual" = "$expected" ] || fail "checksum verification failed"
printf 'Checksum verified.\n'

tar -xzf "$tmp_dir/$archive" -C "$tmp_dir"
release_dir="$tmp_dir/tenzai-$version-$target"
[ -x "$release_dir/tenzai" ] || fail "release archive does not contain the tenzai executable"

if [ -n "${TENZAI_INSTALL_DIR:-}" ]; then
    install_dir="$TENZAI_INSTALL_DIR"
    dir_is_writable "$install_dir" || fail "install directory is not writable: $install_dir"
else
    install_dir="$(default_install_dir)"
fi

destination="$install_dir/tenzai"
partial="$install_dir/.tenzai.partial.$$"

printf 'Installing Tenzai CLI to %s...\n' "$destination"
cp "$release_dir/tenzai" "$partial" || fail "could not copy tenzai to $install_dir"
chmod 755 "$partial" || fail "could not make tenzai executable"
mv -f "$partial" "$destination" || fail "could not install tenzai to $destination"
partial=""

printf 'Tenzai CLI %s installed successfully.\n' "$version"
case ":${PATH:-}:" in
    *":$install_dir:"*) ;;
    *) printf 'Add %s to your PATH to run tenzai.\n' "$install_dir" ;;
esac
