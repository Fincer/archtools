# Add user-specific path definitions to PATH
# variable. Set only unique values to PATH,
# keeping current order.
#
# NOTE: Refer to your distribution documentation
# regarding to behavior of shell environment and
# sourcing of /etc/profile & /etc/profile.d/* files
# when using shell non-interactively.

[ -z "${HOME}" ] && return 0
[ -z "${PATH}" ] && return 0
[ -n "${__PATH}" ] && return 0
[ -n "${__USER_PATHS}" ] && return 0
command -v -p awk >/dev/null 2>&1 || return 0

__USER_PATHS="${HOME}/.local/bin"

__PATH=$(awk -v __path="${__USER_PATHS}:${PATH}" '
  BEGIN {

    # Store individual values of environment variable
    # __PATH into local variable "paths". Split by using
    # character ":".
    split(__path,paths,":");

    # For each value in paths, print the value if
    # not already stored in map variable "a",
    # and length of the value is greater than zero.
    for (i=0; i<length(paths); i++) {
      if (!a[paths[i]] && length(paths[i]) > 0) {
        a[paths[i]] = "seen";
        printf "%s%s", sep, paths[i];
        sep=":";
      }
    }

  }
')

export PATH="${__PATH}"

unset __PATH __USER_PATHS
