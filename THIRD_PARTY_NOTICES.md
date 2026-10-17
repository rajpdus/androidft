# Third-party notices

The release build of AndroidFT bundles two libraries inside the app:

| Library | Version | License | Source |
|---|---|---|---|
| libmtp | 1.1.23 | LGPL-2.1-or-later | https://github.com/libmtp/libmtp |
| libusb | 1.0.30 | LGPL-2.1-or-later | https://github.com/libusb/libusb |

Both are shipped unmodified as dynamic libraries (`Contents/Frameworks/`), as
built by Homebrew, so they can be replaced by the user as the LGPL requires.
Their licence texts are available at the links above and in the Homebrew
formulae `libmtp` and `libusb`.

"Android" is a trademark of Google LLC. AndroidFT is an independent project and
is not affiliated with or endorsed by Google.
