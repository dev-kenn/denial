/// Desktop-entry metadata shared with Denial's application catalog.
///
/// [exec] is desktop-entry data, not a shell command for plugins to execute.
/// Application launching remains a native runtime operation.
class const DesktopApp({
  required final String id,
  required final String name,
  required final String exec,
  required final String desktopPath,
  required final List<String> categories,
  final List<String> keywords = const <String>[],
  final String? icon,
  final String? iconPath,
  final String? startupWmClass,
  final List<DesktopAppAction> actions = const <DesktopAppAction>[],
  /// False when the entry sets `X-Denial-Terminate=false`: its launch command
  /// is a short-lived client, so ending its process would not end the app.
  final bool terminable = true,
}) {
  String get searchableText =>
      <String>[id, name, ...categories, ...keywords].join(' ').toLowerCase();
}

/// One `[Desktop Action ...]` group of a desktop entry, such as Uninstall.
///
/// [exec] is desktop-entry data, like [DesktopApp.exec].
class const DesktopAppAction({
  required final String id,
  required final String name,
  required final String exec,
});
