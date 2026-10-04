# Machine-specific Android build environment. Sourced by lib/common.sh.
#
# The paths live outside every project, in ~/.config/expo-build/env.sh (or the
# file named by EXPO_BUILD_ENV), because they belong to the machine, not the app:
#
#   export ANDROID_HOME="/usr/local/share/android-commandlinetools"
#   export JAVA_HOME="$(brew --prefix openjdk@17)/libexec/openjdk.jdk/Contents/Home"
#
# They're often already exported by ~/.zshrc, but non-interactive shells
# (scripts, Claude's Bash tool) never read that. JAVA_HOME must be JDK 17: newer
# JDKs fail React Native's Gradle plugin resolution.

_expo_build_env="${EXPO_BUILD_ENV:-$HOME/.config/expo-build/env.sh}"
if [ -f "$_expo_build_env" ]; then
  # shellcheck source=/dev/null
  source "$_expo_build_env"
fi
unset _expo_build_env

[ -n "${ANDROID_HOME:-}" ] || die "ANDROID_HOME is not set — create ~/.config/expo-build/env.sh (see README)"
[ -n "${JAVA_HOME:-}" ] || die "JAVA_HOME is not set — create ~/.config/expo-build/env.sh (see README)"

export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
