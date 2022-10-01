# Arch Linux tools

Various command line tools for Arch Linux

## About

This repository has various practical developer/sysadmin-oriented tools for Arch Linux.

----------------------

## Contents

- `bash.bashrc`

  - Drop into `/etc/` system folder
  - Use with `bash.custom` file

- `bash.custom`

  - Drop into `/etc/` system folder or install using [PKGBUILD](tools/PKGBUILD)
  - Enable various customizations in your bash environment
  - Improve usability and visual feedback of bash shell

### [tools](tools)

Various shell tools, bundled in a custom `archtools` package. See [PKGBUILD](tools/PKGBUILD) and contents of shell tools for details.

|      Tool      |                                          Description                                          |
|----------------|-----------------------------------------------------------------------------------------------|
| `archrisks`    | Get security risk severity & count of installed packages on Arch Linux                        |
| `bininfo`      | Show information about an executable in PATH on Arch Linux                                    |
| `buildpkg`     | Build a local package on the current directory which has `PKGBUILD` on Arch Linux             |
| `deltmpfiles`  | Delete current temporary files from pre-defined locations                                     |
| `extract`      | Extract wide range of various archive types with native tools                                 |
| `findinpkg`    | Find text patterns & print occurences with matching lines numbers in Arch Linux package files |
| `findmatch`    | Grep/List matching strings in a specific folder                                               |
| `findpkg`      | Search package in official Arch Linux repositories                                            |
| `genmac`       | Generate a random MAC address for a Systemd-configured network interface                      |
| `getsource`    | Get build files from official Arch Linux repositories and AUR repositories                    |
| `killns`       | Send `signal` to a process running in a specific Linux namespace (see `man 7 signal`)         |
| `killprocess`  | Kill a process by its name                                                                    |
| `missinglibs`  | List missing package libraries for a local, installed Arch Linux package                      |
| `nowner`       | Find orphan files on various Linux distributions                                              |
| `pkgdeps`      | Recursive shared library & executable dependency finder for Arch Linux                        |
| `pkginfo`      | Gather package information with pacman on Arch Linux                                          |
| `psns`         | List processes, their users and PIDs and their namespace name in current Linux namespaces     |
| `showpkg`      | Show specific package version - installed and available version                               |
| `specialchars` | Show special characters which need to be escaped in shell                                     |
| `ssh_timezone` | Automatically retrieve timezone information for SSH users                                     |
| `tputcolors`   | Display shell colors                                                                          |
| `whichcmd`     | Find available commands in PATH by input syntax                                               |
| `whichport`    | Which TCP/UDP port number is associated with an application protocol                          |
| `whichservice` | Which application protocol is associated with a TCP/UDP port number                           |

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

### [stderred](stderred)

[PKGBUILD](stderred/PKGBUILD) for `stderred`. As the build script description says, it `hooks into STDERR output to print all CLI errors in red"`.

----------------------

## License

This repository uses GPLv3 license. Please see [LICENSE](https://github.com/Fincer/archtools/blob/master/LICENSE) files for details.
