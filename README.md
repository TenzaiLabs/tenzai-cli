# Tenzai CLI

The command-line interface for Tenzai.

## Install

On macOS or Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/TenzaiLabs/tenzai-cli/main/install.sh | sh
```

The installer downloads the latest public CLI release, verifies its checksum,
and installs the `tenzai` binary. It uses `~/.local/bin` by default; set
`TENZAI_INSTALL_DIR` to install it elsewhere:

```sh
curl -fsSL https://raw.githubusercontent.com/TenzaiLabs/tenzai-cli/main/install.sh | TENZAI_INSTALL_DIR=/usr/local/bin sh
```

To generate shell completions, run `tenzai completion --help`.

Windows users and users who prefer to install manually can download an archive
from the [releases page](https://github.com/TenzaiLabs/tenzai-cli/releases/latest).

## Get started

```sh
tenzai --help
```

## License

Tenzai CLI is proprietary software. See [LICENSE](LICENSE) for details.
