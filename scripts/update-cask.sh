#!/bin/zsh
# Usage: scripts/update-cask.sh 0.1.0 <sha256>
# Writes Casks/androidft.rb for the rajpdus/homebrew-tap repository to stdout.
set -euo pipefail
VERSION=${1:?version}; SHA=${2:?sha256}
cat <<RUBY
cask "androidft" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/rajpdus/androidft/releases/download/v#{version}/AndroidFT-#{version}.zip"
  name "AndroidFT"
  desc "Native Apple Silicon file transfer app for Android phones (MTP)"
  homepage "https://github.com/rajpdus/androidft"

  depends_on arch: :arm64
  depends_on macos: ">= :sonoma"

  app "AndroidFT.app"

  caveats <<~EOS
    AndroidFT is signed ad hoc (no Apple Developer ID), so macOS Gatekeeper
    will refuse to open it after download. Either install with
      brew install --cask --no-quarantine rajpdus/tap/androidft
    or, after a normal install, run
      xattr -dr com.apple.quarantine /Applications/AndroidFT.app

    If Google's Android File Transfer is installed, quit it and remove its
    "Android File Transfer Agent" login item: it grabs the phone's USB
    interface the moment a device is plugged in.
  EOS

  zap trash: [
    "~/Library/Preferences/com.rajpdus.androidft.plist",
    "~/Library/Saved Application State/com.rajpdus.androidft.savedState",
  ]
end
RUBY
