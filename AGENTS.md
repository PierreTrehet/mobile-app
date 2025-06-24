**Coding Guidelines**

- JS packages for blockchain interaction live under `lib/js/packages/reef-mobile-js`.
- Install JS dependencies by running `yarn` inside `lib/js/`.
- Start/compile the JS bundles with `yarn start` in the same directory.

**Flutter integration with JS**

- WebView code loads the compiled JS bundle `lib/js/packages/reef-mobile-js/dist/index.js`.
- The global `FlutterJS` class inside this bundle exposes a bridge.
- Flutter calls JS via the function registered by `FlutterJS.registerMobileSubscriptionMethod`.
  The JS results are sent back through `window.postMessage`.
- Global objects such as `reefState`, `tokenUtil`, `keyring` and others are attached to `window` for use via the bridge.

**Development Tasks**

- When editing Mobx classes, run `flutter pub run build_runner watch`.
- For localization changes run `flutter gen-l10n`.


