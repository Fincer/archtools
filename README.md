# Arch Linux tools

Various command line tools for Arch Linux

## About

This repository has various practical developer/sysadmin-oriented tools to Arch Linux.

----------------------

## Contents

### [tools](tools)

Various shell tools, bundled in a custom `archtools` package. See [PKGBUILD](tools/PKGBUILD) and contents of shell tools for details.

### [pacman](pacman)

**DISCLAIMER**: These modifications are fully compliant with Pacman version `5.1.3-1`. Newer versions have not been tested.

|                File                |                                                                                                                                                             Description                                                                                                                                                             | Permissions |
|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------|
| `/usr/local/bin/makepkg`           | Get sources without security checks; Ask user whether to install missing deps automatically; Prompt whether to enforce package compilation without missing deps; Implement support for `--getsource` parameter (works with, and requires [getsource](tools/getsource.sh) command)                                                   | `0755`      |
| `/usr/local/bin/pacmankeycheck.sh` | Check age of Pacman PGP/GPG public key ring files and prompt updating them during `pacman` execution if they are too old (30 days).                                                                                                                                                                                                 | `0644`      |
| `/usr/local/bin/pacman`            | A simple wrapper which runs `pacmankeycheck.sh` and then your original `pacman` command.                                                                                                                                                                                                                                            | `0755`      |
| `/usr/share/makepkg/source/git.sh` | Modified `makepkg` source file; allow use of additional `git` command parameters.                                                                                                                                                                                                                                                   | `0644`      |
| `/usr/share/makepkg/source.sh`     | Modified `makepkg` source file; use shallow git repository cloning (parameter `--depth 1`) instead of cloning full git repository when downloading package source code with `makepkg`. This is useful with large packages when only the most recent files from them are wanted and full git repository cloning mode is not desired. | `0644`      |

File paths above represent the intended deployment location on your Arch Linux file system.

----------------------

## License

This repository uses GPLv3 license. Please see [LICENSE](https://github.com/Fincer/archtools/blob/master/LICENSE) files for details.
