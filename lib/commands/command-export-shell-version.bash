# -*- sh -*-
# shellcheck source=lib/functions/versions.bash
. "$(dirname "$(dirname "$0")")/lib/functions/versions.bash"

unset_all_fish() {
  printf "for var in (env | awk -F= '/^ASDF_[A-Za-z0-9_]+_VERSION=/ {print \$1}')\n"
  printf "    echo Removing Env: \$var\n"
  printf "    set -e \$var\n"
  printf "end\n"
}
unset_all() {
  printf "for var in \$(env | awk -F= '/^ASDF_[A-Za-z0-9_]+_VERSION=/ {print \$1}'); do\n"
  printf "    echo Removing Env: "
  printf "    \$var\n"
  printf "    unset -v \$var\n"
  printf "done\n"
}

# Output from this command must be executable shell code
shell_command() {
  local asdf_shell="$1"
  shift

  if [ "$#" -lt "2" ] && [ "$1" != "--unset-all" ]; then
    printf "Usage: asdf shell {<name> {<version>|--unset}|--unset-all}\n" >&2
    printf "false\n"
    exit 1
  fi

  local plugin=$1
  local version=$2

  if [ "$plugin" = "--unset-all" ]; then
    case "$asdf_shell" in
    fish)
      unset_all_fish
      ;;
    elvish)
      # TODO
      printf "asdf: Flag '--unset-all' not implemented for Elvish shell" >&2
      ;;
    *)
      unset_all
      ;;
    esac

    exit 0
  fi

  local upcase_name
  upcase_name=$(tr '[:lower:]-' '[:upper:]_' <<<"$plugin")
  local version_env_var="ASDF_${upcase_name}_VERSION"

  if [ "$version" = "--unset" ]; then
    case "$asdf_shell" in
    fish)
      printf "set -e %s\n" "$version_env_var"
      ;;
    elvish)
      # Elvish doesn't have a `source` command, and eval is banned, so the
      # var name and value are printed on separate lines for asdf.elv to parse
      # and pass to unset-env.
      printf "unset-env\n%s" "$version_env_var"
      ;;
    pwsh)
      printf '%s\n' "if (\$(Test-Path Env:$version_env_var) -eq 'True') { Remove-Item Env:$version_env_var }"
      ;;
    *)
      printf "unset %s\n" "$version_env_var"
      ;;
    esac
    exit 0
  fi
  if [ "$version" = "latest" ]; then
    version=$(latest_command "$plugin")
  fi
  if ! (check_if_version_exists "$plugin" "$version"); then
    version_not_installed_text "$plugin" "$version" 1>&2
    printf "false\n"
    exit 1
  fi

  case "$asdf_shell" in
  fish)
    printf "set -gx %s \"%s\"\n" "$version_env_var" "$version"
    ;;
  elvish)
    # Elvish doesn't have a `source` command, and eval is banned, so the
    # var name and value are printed on separate lines for asdf.elv to parse
    # and pass to set-env.
    printf "set-env\n%s\n%s" "$version_env_var" "$version"
    ;;
  pwsh)
    printf '%s\n' "\$Env:$version_env_var = '$version'"
    ;;
  *)
    printf "export %s=\"%s\"\n" "$version_env_var" "$version"
    ;;
  esac
}

shell_command "$@"
