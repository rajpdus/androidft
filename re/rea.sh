#!/bin/zsh
# Wrapper: run REA CLI on Homebrew Node 26 with Ghidra configured.
export PATH=/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin
export GHIDRA_INSTALL_DIR=/opt/homebrew/opt/ghidra/libexec
export JAVA_HOME=/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home
exec npx -y rea-agents@6.5.0 "$@"
