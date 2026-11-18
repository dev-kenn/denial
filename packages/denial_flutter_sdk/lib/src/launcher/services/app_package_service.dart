import 'dart:io';

/// Finds the pacman package that installed an application and builds the
/// command that removes it.
class AppPackageService {
  const AppPackageService();

  /// Packages the shell must never offer to remove: Denial and Droidloom
  /// themselves, and the base system.
  static const List<String> _protectedPrefixes = <String>[
    'denial',
    'droidloom',
    'linux',
    'systemd',
  ];
  static const Set<String> _protectedPackages = <String>{
    'base',
    'bash',
    'coreutils',
    'filesystem',
    'glibc',
    'pacman',
    'polkit',
    'sudo',
  };
  static final RegExp _packageName = RegExp(r'^[a-z0-9@._+-]+$');

  /// The one package that owns [desktopPath], or null when it is not a system
  /// file (for example a launcher in the user's own folder) or pacman cannot
  /// say.
  Future<String?> owningPackage(String desktopPath) async {
    if (!desktopPath.startsWith('/usr/')) {
      return null;
    }
    try {
      final result = await Process.run('pacman', <String>['-Qoq', desktopPath]);
      if (result.exitCode != 0) {
        return null;
      }
      final owners = '${result.stdout}'
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);
      return owners.length == 1 ? owners.single : null;
    } on ProcessException {
      return null;
    }
  }

  /// Whether the shell may offer to remove [package].
  bool isRemovable(String package) {
    if (!_packageName.hasMatch(package) ||
        _protectedPackages.contains(package)) {
      return false;
    }
    return !_protectedPrefixes.any(package.startsWith);
  }

  /// Removes [package] only: pacman refuses when another package needs it.
  /// `pkexec` asks for authentication through Denial's polkit agent.
  List<String> uninstallCommand(String package) => <String>[
    'pkexec',
    'pacman',
    '-R',
    '--noconfirm',
    package,
  ];
}
