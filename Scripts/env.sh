# Source me: puts the repo-local libaria2 (Scripts/libaria2.sh) on PKG_CONFIG_PATH.
#   source Scripts/env.sh && xed .
_ariakit_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
export PKG_CONFIG_PATH="$_ariakit_root/.deps/libaria2/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
unset _ariakit_root
