import 'dart:io';
import '../models/optional_package.dart';
import 'native_bridge.dart';

/// Manages SSH server operations inside the proot environment.
class SshService {
  static String? _rootfsDir;

  static Future<String> _getRootfsDir() async {
    if (_rootfsDir != null) return _rootfsDir!;
    final filesDir = await NativeBridge.getFilesDir();
    _rootfsDir = '$filesDir/rootfs/ubuntu';
    return _rootfsDir!;
  }

  /// Check if OpenSSH is installed.
  static Future<bool> isInstalled() async {
    final rootfs = await _getRootfsDir();
    return File('$rootfs/${OptionalPackage.sshPackage.checkPath}').existsSync();
  }

  /// Check if sshd is currently running inside proot.
  static Future<bool> isSshdRunning() async {
    try {
      final result = await NativeBridge.runInProot('pgrep -x sshd', timeout: 10);
      return result.trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Generate host keys if they don't exist, then start sshd on [port].
  /// Default port is 8022 (port 22 requires true root which proot can't provide).
  static Future<void> startSshd({int port = 8022}) async {
    await NativeBridge.runInProot(
      'mkdir -p /run/sshd && '
      'test -f /etc/ssh/ssh_host_rsa_key || ssh-keygen -A && '
      '/usr/sbin/sshd -p $port',
      timeout: 30,
    );
  }

  /// Stop all sshd processes.
  static Future<void> stopSshd() async {
    try {
      await NativeBridge.runInProot('pkill sshd', timeout: 10);
    } catch (_) {
      // Already stopped
    }
  }

  /// Set the root password inside proot.
  static Future<void> setPassword(String password) async {
    // Shell-escape the password to prevent injection
    final escaped = password.replaceAll("'", "'\\''");
    await NativeBridge.runInProot(
      "echo 'root:$escaped' | chpasswd",
      timeout: 15,
    );
  }

  /// Get the device's IP addresses.
  static Future<List<String>> getIpAddresses() async {
    try {
      final result = await NativeBridge.runInProot('hostname -I', timeout: 10);
      return result
          .trim()
          .split(RegExp(r'\s+'))
          .where((ip) => ip.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
