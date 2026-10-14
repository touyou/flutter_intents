/// How much authentication iOS demands before an App Intent runs.
///
/// Maps to the Swift `IntentAuthenticationPolicy` enum (iOS 16+). Set it with
/// `@IntentSpec(authenticationPolicy:)` and the generated `AppIntent` gains
/// `static let authenticationPolicy: IntentAuthenticationPolicy = ...`. When
/// the field is left unset nothing is emitted and the system default applies.
enum IntentAuthentication {
  /// The intent may run at any time, including while the device is locked.
  /// Generates `.alwaysAllowed`.
  alwaysAllowed,

  /// The person must authenticate before the intent runs.
  /// Generates `.requiresAuthentication`.
  requiresAuthentication,

  /// The device running the intent must be unlocked, even when the request
  /// came from an already authenticated Apple Watch or another remote device.
  /// Use it when the handler reads data that is encrypted while the device is
  /// locked. Generates `.requiresLocalDeviceAuthentication`.
  requiresLocalDeviceAuthentication,
}
