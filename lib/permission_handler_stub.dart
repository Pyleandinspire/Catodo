import 'dart:io' show Platform;

/// Permission Handler Stub for non-Android platforms
/// Windows and macOS don't need runtime notification permissions
class Permission {
  static final notification = _PermissionStub();
}

class _PermissionStub {
  /// Stub implementation that always returns true for non-Android platforms
  /// Windows and macOS don't require runtime notification permissions
  Future<bool> request() async {
    // On Windows and macOS, notification permissions are granted at install time
    // or through system settings, not runtime requests
    return true;
  }
}
