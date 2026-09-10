/// 读取 Windows 系统代理注册表（Internet Settings）。
///
/// 只读 `ProxyEnable` / `ProxyServer`，不写注册表、不改系统设置。
/// 通过 advapi32 直接调用，避免派生 `reg.exe` 控制台进程。
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

const int _hkeyCurrentUser = 0x80000001;
const int _hkeyLocalMachine = 0x80000002;
const int _keyRead = 0x20019;
const int _regSz = 1;

typedef _RegOpenKeyExWNative =
    Int32 Function(
      IntPtr hKey,
      Pointer<Utf16> lpSubKey,
      Uint32 ulOptions,
      Uint32 samDesired,
      Pointer<IntPtr> phkResult,
    );
typedef _RegOpenKeyExWDart =
    int Function(
      int hKey,
      Pointer<Utf16> lpSubKey,
      int ulOptions,
      int samDesired,
      Pointer<IntPtr> phkResult,
    );

typedef _RegQueryValueExWNative =
    Int32 Function(
      IntPtr hKey,
      Pointer<Utf16> lpValueName,
      Pointer<Uint32> lpReserved,
      Pointer<Uint32> lpType,
      Pointer<Uint8> lpData,
      Pointer<Uint32> lpcbData,
    );
typedef _RegQueryValueExWDart =
    int Function(
      int hKey,
      Pointer<Utf16> lpValueName,
      Pointer<Uint32> lpReserved,
      Pointer<Uint32> lpType,
      Pointer<Uint8> lpData,
      Pointer<Uint32> lpcbData,
    );

typedef _RegCloseKeyNative = Int32 Function(IntPtr hKey);
typedef _RegCloseKeyDart = int Function(int hKey);

_RegOpenKeyExWDart? _regOpenKeyExW;
_RegQueryValueExWDart? _regQueryValueExW;
_RegCloseKeyDart? _regCloseKey;
bool _bindingsReady = false;

void _ensureBindings() {
  if (_bindingsReady) return;
  _bindingsReady = true;
  if (!Platform.isWindows) return;
  try {
    final lib = DynamicLibrary.open('advapi32.dll');
    _regOpenKeyExW = lib
        .lookupFunction<_RegOpenKeyExWNative, _RegOpenKeyExWDart>(
          'RegOpenKeyExW',
        );
    _regQueryValueExW = lib
        .lookupFunction<_RegQueryValueExWNative, _RegQueryValueExWDart>(
          'RegQueryValueExW',
        );
    _regCloseKey = lib.lookupFunction<_RegCloseKeyNative, _RegCloseKeyDart>(
      'RegCloseKey',
    );
  } catch (_) {
    _regOpenKeyExW = null;
    _regQueryValueExW = null;
    _regCloseKey = null;
  }
}

const String _internetSettings =
    r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

/// 读取系统代理服务器地址（原始值）。
///
/// 返回 null 表示当前用户/机器没有启用系统代理或读取失败。
String? readWindowsProxyServer() {
  _ensureBindings();
  if (_regOpenKeyExW == null) return null;
  final enable = _readString(_hkeyCurrentUser, 'ProxyEnable');
  final enabled = (enable == null || enable.trim() != '0');
  final server =
      _readString(_hkeyCurrentUser, 'ProxyServer') ??
      _readString(_hkeyLocalMachine, 'ProxyServer');
  if (!enabled) return null;
  return server;
}

String? _readString(int root, String name) {
  final openKey = _regOpenKeyExW;
  final queryValue = _regQueryValueExW;
  final closeKey = _regCloseKey;
  if (openKey == null || queryValue == null || closeKey == null) return null;

  final subKey = _internetSettings.toNativeUtf16();
  final valueName = name.toNativeUtf16();
  final hKey = calloc<IntPtr>();
  const bufferBytes = 2048;
  final buffer = calloc<Uint8>(bufferBytes);
  final size = calloc<Uint32>()..value = bufferBytes;
  final type = calloc<Uint32>();
  try {
    final opened = openKey(root, subKey, 0, _keyRead, hKey);
    if (opened != 0) return null;
    final status = queryValue(
      hKey.value,
      valueName,
      nullptr,
      type,
      buffer,
      size,
    );
    if (status != 0 || type.value != _regSz) return null;
    final length = size.value;
    if (length < 2 || length > bufferBytes) return null;
    return buffer.cast<Utf16>().toDartString();
  } catch (_) {
    return null;
  } finally {
    if (hKey.value != 0) closeKey(hKey.value);
    calloc
      ..free(subKey)
      ..free(valueName)
      ..free(hKey)
      ..free(buffer)
      ..free(size)
      ..free(type);
  }
}
