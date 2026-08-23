/// 手写 Win32 FFI 绑定（零第三方包装，保证 isolate 内可用）。
///
/// Dart FFI 规范要求：
///  * Struct 字段必须声明为 `int` / `Pointer`，并用 `@IntPtr()` / `@Uint32()` 等注解修饰
///  * NativeFunction 的 Dart 侧签名参数/返回值必须是标准 Dart 类型（`int`）
library;

// MSG 结构体中的对齐填充字段仅服务于 ABI 布局，分析器会误报 unused_field。
// ignore_for_file: unused_field

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ─────────────────────────────────────────────────────────────
// 常量
// ─────────────────────────────────────────────────────────────
const int eventSystemForeground = 0x0003;
const int winEventOutOfContext = 0x0000;
const int winEventSkipOwnProcess = 0x0002;

const int processQueryLimitedInformation = 0x1000;

const int qsAllInput = 0x04FF;
const int mwmoInputAvailable = 0x0002;

const int waitObject0 = 0;
const int waitTimeout = 0x00000102;
const int waitFailed = 0xFFFFFFFF;

const int wmDestroy = 0x0002;
const int wmQuit = 0x0012;
const int wmClose = 0x0010;
const int wmPowerBroadcast = 0x0218;
const int pbtApmSuspend = 0x0004;
const int pbtApmResumeSuspend = 0x0007;
const int pbtApmResumeAutomatic = 0x0012;
const int wmWtsSessionChange = 0x02B1;
const int wtsSessionLock = 0x7;
const int wtsSessionUnlock = 0x8;
const int notifyForThisSession = 0;

const int deviceNotifyWindowHandle = 0x00000000;

// NtQueryInformationProcess 的 ProcessCommandLineInformation 类（60）。
const int processCommandLineInformation = 60;

// ─────────────────────────────────────────────────────────────
// 结构体
// ─────────────────────────────────────────────────────────────

/// Win64 下 MSG 结构（48 字节）。
final class Msg extends Struct {
  @IntPtr()
  external int hwnd;

  @Uint32()
  external int message;

  @Uint32()
  external int _padding;

  @IntPtr()
  external int wParam;

  @IntPtr()
  external int lParam;

  @Uint32()
  external int time;

  @Int32()
  external int ptX;

  @Int32()
  external int ptY;

  @Uint32()
  external int _tail;
}

final class WndClassExW extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int style;

  external Pointer<
    NativeFunction<IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr)>
  >
  lpfnWndProc;

  @Int32()
  external int cbClsExtra;

  @Int32()
  external int cbWndExtra;

  @IntPtr()
  external int hInstance;

  @IntPtr()
  external int hIcon;

  @IntPtr()
  external int hCursor;

  @IntPtr()
  external int hbrBackground;

  external Pointer<Utf16> lpszMenuName;
  external Pointer<Utf16> lpszClassName;

  @IntPtr()
  external int hIconSm;
}

// ─────────────────────────────────────────────────────────────
// 函数指针 Native 签名（供 NativeCallable 与 lookupFunction 使用）
// ─────────────────────────────────────────────────────────────
typedef WinEventProcNative =
    Void Function(IntPtr, Uint32, IntPtr, Int32, Int32, Uint32, Uint32);
typedef WndProcNative = IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr);

// ─────────────────────────────────────────────────────────────
// 动态库导入
// ─────────────────────────────────────────────────────────────
final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final DynamicLibrary _wtsapi32 = DynamicLibrary.open('wtsapi32.dll');
final DynamicLibrary _ntdll = DynamicLibrary.open('ntdll.dll');

// ─── user32 ──────────────────────────────────────────────────
final int Function(
  int,
  int,
  int,
  Pointer<NativeFunction<WinEventProcNative>>,
  int,
  int,
  int,
)
_setWinEventHook = _user32
    .lookupFunction<
      IntPtr Function(
        Uint32,
        Uint32,
        IntPtr,
        Pointer<NativeFunction<WinEventProcNative>>,
        Uint32,
        Uint32,
        Uint32,
      ),
      int Function(
        int,
        int,
        int,
        Pointer<NativeFunction<WinEventProcNative>>,
        int,
        int,
        int,
      )
    >('SetWinEventHook');

final int Function(int) _unhookWinEvent = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'UnhookWinEvent',
    );

final int Function() _getForegroundWindow = _user32
    .lookupFunction<IntPtr Function(), int Function()>('GetForegroundWindow');

final int Function(int, Pointer<Uint32>) _getWindowThreadProcessId = _user32
    .lookupFunction<
      Uint32 Function(IntPtr, Pointer<Uint32>),
      int Function(int, Pointer<Uint32>)
    >('GetWindowThreadProcessId');

final int Function(int) _isWindowVisible = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'IsWindowVisible',
    );

final int Function(int) _isIconic = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('IsIconic');

final int Function(int, Pointer<Utf16>, int) _getWindowTextW = _user32
    .lookupFunction<
      Int32 Function(IntPtr, Pointer<Utf16>, Int32),
      int Function(int, Pointer<Utf16>, int)
    >('GetWindowTextW');

final int Function(Pointer<WndClassExW>) _registerClassExW = _user32
    .lookupFunction<
      Uint16 Function(Pointer<WndClassExW>),
      int Function(Pointer<WndClassExW>)
    >('RegisterClassExW');

final int Function(
  int,
  Pointer<Utf16>,
  Pointer<Utf16>,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
  int,
)
_createWindowExW = _user32
    .lookupFunction<
      IntPtr Function(
        Uint32,
        Pointer<Utf16>,
        Pointer<Utf16>,
        Uint32,
        Int32,
        Int32,
        Int32,
        Int32,
        IntPtr,
        IntPtr,
        IntPtr,
        IntPtr,
      ),
      int Function(
        int,
        Pointer<Utf16>,
        Pointer<Utf16>,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
        int,
      )
    >('CreateWindowExW');

final int Function(int) _destroyWindow = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('DestroyWindow');

final int Function(Pointer<Utf16>, int) _unregisterClassW = _user32
    .lookupFunction<
      Int32 Function(Pointer<Utf16>, Uint16),
      int Function(Pointer<Utf16>, int)
    >('UnregisterClassW');

final int Function(int, int, int, int) _defWindowProcW = _user32
    .lookupFunction<
      IntPtr Function(IntPtr, Uint32, IntPtr, IntPtr),
      int Function(int, int, int, int)
    >('DefWindowProcW');

final int Function(int, Pointer<IntPtr>, int, int, int)
_msgWaitForMultipleObjectsEx = _user32
    .lookupFunction<
      Uint32 Function(Uint32, Pointer<IntPtr>, Uint32, Uint32, Uint32),
      int Function(int, Pointer<IntPtr>, int, int, int)
    >('MsgWaitForMultipleObjectsEx');

final int Function(Pointer<Msg>, int, int, int, int) _peekMessageW = _user32
    .lookupFunction<
      Int32 Function(Pointer<Msg>, IntPtr, Uint32, Uint32, Uint32),
      int Function(Pointer<Msg>, int, int, int, int)
    >('PeekMessageW');

final int Function(Pointer<Msg>) _translateMessage = _user32
    .lookupFunction<Int32 Function(Pointer<Msg>), int Function(Pointer<Msg>)>(
      'TranslateMessage',
    );

final int Function(Pointer<Msg>) _dispatchMessageW = _user32
    .lookupFunction<IntPtr Function(Pointer<Msg>), int Function(Pointer<Msg>)>(
      'DispatchMessageW',
    );

final int Function(int, int) _registerSuspendResumeNotification = _user32
    .lookupFunction<IntPtr Function(IntPtr, Uint32), int Function(int, int)>(
      'RegisterSuspendResumeNotification',
    );

final int Function(int) _unregisterSuspendResumeNotification = _user32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'UnregisterSuspendResumeNotification',
    );

// ─── kernel32 ────────────────────────────────────────────────
final int Function(int, int, int, Pointer<Utf16>) _createEventW = _kernel32
    .lookupFunction<
      IntPtr Function(Uint32, Int32, Uint32, Pointer<Utf16>),
      int Function(int, int, int, Pointer<Utf16>)
    >('CreateEventW');

final int Function(int) _setEvent = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('SetEvent');

final int Function(int) _closeHandle = _kernel32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>('CloseHandle');

final int Function(int, int, int) _openProcess = _kernel32
    .lookupFunction<
      IntPtr Function(Uint32, Int32, Uint32),
      int Function(int, int, int)
    >('OpenProcess');

final int Function(int, int, Pointer<Utf16>, Pointer<Uint32>)
_queryFullProcessImageNameW = _kernel32
    .lookupFunction<
      Int32 Function(IntPtr, Uint32, Pointer<Utf16>, Pointer<Uint32>),
      int Function(int, int, Pointer<Utf16>, Pointer<Uint32>)
    >('QueryFullProcessImageNameW');

final int Function(Pointer<Utf16>, int, Pointer<Utf16>, Pointer<Uint32>)
_getLongPathNameW = _kernel32
    .lookupFunction<
      Uint32 Function(Pointer<Utf16>, Uint32, Pointer<Utf16>, Pointer<Uint32>),
      int Function(Pointer<Utf16>, int, Pointer<Utf16>, Pointer<Uint32>)
    >('GetLongPathNameW');

final int Function(Pointer<Utf16>) _getModuleHandleW = _kernel32
    .lookupFunction<
      IntPtr Function(Pointer<Utf16>),
      int Function(Pointer<Utf16>)
    >('GetModuleHandleW');

// ─── wtsapi32 ────────────────────────────────────────────────
final int Function(int, int) _wtsRegisterSessionNotification = _wtsapi32
    .lookupFunction<Int32 Function(IntPtr, Uint32), int Function(int, int)>(
      'WTSRegisterSessionNotification',
    );

final int Function(int) _wtsUnRegisterSessionNotification = _wtsapi32
    .lookupFunction<Int32 Function(IntPtr), int Function(int)>(
      'WTSUnRegisterSessionNotification',
    );

// ─── ntdll ───────────────────────────────────────────────────
final int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)
_ntQueryInformationProcess = _ntdll
    .lookupFunction<
      Int32 Function(IntPtr, Int32, Pointer<Void>, Uint32, Pointer<Uint32>),
      int Function(int, int, Pointer<Void>, int, Pointer<Uint32>)
    >('NtQueryInformationProcess');

// ─────────────────────────────────────────────────────────────
// Dart 友好包装
// ─────────────────────────────────────────────────────────────

/// 订阅 EVENT_SYSTEM_FOREGROUND。返回 0 表示失败。
int setWinEventHook(Pointer<NativeFunction<WinEventProcNative>> proc) =>
    _setWinEventHook(
      eventSystemForeground,
      eventSystemForeground,
      0,
      proc,
      0,
      0,
      winEventOutOfContext,
    );

bool unhookWinEvent(int hook) => _unhookWinEvent(hook) != 0;

int getForegroundWindow() => _getForegroundWindow();

/// 返回前台窗口所属进程 PID；失败返回 0。
int pidForWindow(int hwnd) {
  final pid = calloc<Uint32>();
  try {
    final r = _getWindowThreadProcessId(hwnd, pid);
    if (r == 0) return 0;
    return pid.value;
  } finally {
    calloc.free(pid);
  }
}

bool isWindowVisible(int hwnd) => _isWindowVisible(hwnd) != 0;
bool isIconic(int hwnd) => _isIconic(hwnd) != 0;

String windowText(int hwnd) {
  final buf = calloc<Uint16>(512).cast<Utf16>();
  try {
    final n = _getWindowTextW(hwnd, buf, 512);
    if (n <= 0) return '';
    return buf.toDartString(length: n);
  } finally {
    calloc.free(buf);
  }
}

int registerWatcherWindowClass(
  Pointer<WndClassExW> wc,
  String className,
  int hInstance,
  Pointer<NativeFunction<WndProcNative>> proc,
) {
  final name = className.toNativeUtf16();
  try {
    wc.ref
      ..cbSize = sizeOf<WndClassExW>()
      ..style = 0
      ..lpfnWndProc = proc
      ..cbClsExtra = 0
      ..cbWndExtra = 0
      ..hInstance = hInstance
      ..hIcon = 0
      ..hCursor = 0
      ..hbrBackground = 0
      ..lpszMenuName = nullptr
      ..lpszClassName = name
      ..hIconSm = 0;
    return _registerClassExW(wc);
  } finally {
    calloc.free(name);
  }
}

/// 创建消息专用窗口（父窗口 = -3 HWND_MESSAGE）。
int createMessageOnlyWindow(String className, int hInstance) {
  final cls = className.toNativeUtf16();
  final title = 'BlackOhmWatcher'.toNativeUtf16();
  try {
    const hwndMessage = -3;
    return _createWindowExW(
      0,
      cls,
      title,
      0,
      0,
      0,
      0,
      0,
      hwndMessage,
      0,
      hInstance,
      0,
    );
  } finally {
    calloc.free(cls);
    calloc.free(title);
  }
}

bool destroyWindow(int hwnd) => _destroyWindow(hwnd) != 0;

bool unregisterWindowClass(String className, int hInstance) {
  final name = className.toNativeUtf16();
  try {
    return _unregisterClassW(name, hInstance) != 0;
  } finally {
    calloc.free(name);
  }
}

int defWindowProc(int hwnd, int msg, int wParam, int lParam) =>
    _defWindowProcW(hwnd, msg, wParam, lParam);

/// 阻塞等待内核对象或消息输入。
int msgWaitForMultipleObjectsEx(List<int> handles, int ms) {
  if (handles.isEmpty) {
    return _msgWaitForMultipleObjectsEx(
      0,
      nullptr,
      ms,
      qsAllInput,
      mwmoInputAvailable,
    );
  }
  final arr = calloc<IntPtr>(handles.length);
  for (var i = 0; i < handles.length; i++) {
    arr[i] = handles[i];
  }
  try {
    return _msgWaitForMultipleObjectsEx(
      handles.length,
      arr,
      ms,
      qsAllInput,
      mwmoInputAvailable,
    );
  } finally {
    calloc.free(arr);
  }
}

/// 排空当前线程消息队列；返回 false 表示收到 WM_QUIT。
bool pumpMessages(Pointer<Msg> msg) {
  const pmRemove = 1;
  while (_peekMessageW(msg, 0, 0, 0, pmRemove) != 0) {
    if (msg.ref.message == wmQuit) return false;
    _translateMessage(msg);
    _dispatchMessageW(msg);
  }
  return true;
}

int createShutdownEvent() => _createEventW(0, 1, 0, nullptr);

bool setEvent(int handle) => _setEvent(handle) != 0;
bool closeHandle(int handle) => _closeHandle(handle) != 0;

int openProcessQuery(int pid) =>
    _openProcess(processQueryLimitedInformation, 0, pid);

String? queryProcessImagePath(int processHandle) {
  final buf = calloc<Uint16>(1024).cast<Utf16>();
  final size = calloc<Uint32>();
  try {
    size.value = 1024;
    if (_queryFullProcessImageNameW(processHandle, 0, buf, size) == 0) {
      return null;
    }
    return buf.toDartString(length: size.value);
  } finally {
    calloc.free(buf);
    calloc.free(size);
  }
}

/// 读取另一进程的命令行（通过 NtQueryInformationProcess 的
/// ProcessCommandLineInformation 类，直接返回 UNICODE_STRING，无需读 PEB）。
/// 仅配合 [openProcessQuery] 返回的句柄使用；失败或空返回 null。
String? queryProcessCommandLine(int processHandle) {
  final sizeBuf = calloc<Uint32>();
  var status = _ntQueryInformationProcess(
    processHandle,
    processCommandLineInformation,
    nullptr,
    0,
    sizeBuf,
  );
  final needed = sizeBuf.value;
  calloc.free(sizeBuf);
  // 首次调用通常返回 STATUS_INFO_LENGTH_MISMATCH 并写回所需长度；
  // 查询不到或不需要缓冲区时视为无命令行。
  if (needed < 16) return null;

  final buf = calloc<Uint8>(needed);
  final retLen = calloc<Uint32>();
  status = _ntQueryInformationProcess(
    processHandle,
    processCommandLineInformation,
    buf.cast(),
    needed,
    retLen,
  );
  if (status != 0) {
    calloc.free(buf);
    calloc.free(retLen);
    return null;
  }

  final u16 = buf.cast<Uint16>();
  final lengthBytes = u16[0];
  final ptr = buf.cast<Uint64>()[1];
  final offsetBytes = ptr - buf.address;

  final sb = StringBuffer();
  if (offsetBytes >= 0 && offsetBytes < needed) {
    final start = offsetBytes ~/ 2;
    final count = lengthBytes ~/ 2;
    final end = start + count;
    final maxEnd = needed ~/ 2;
    for (var i = start; i < end && i < maxEnd; i++) {
      sb.writeCharCode(u16[i]);
    }
  }
  calloc.free(buf);
  calloc.free(retLen);
  return sb.toString();
}

String getLongPathName(String path) {
  if (!path.contains('~')) return path;
  final src = path.toNativeUtf16();
  final dst = calloc<Uint16>(1024).cast<Utf16>();
  try {
    final n = _getLongPathNameW(src, 1024, dst, nullptr);
    if (n > 0 && n < 1024) return dst.toDartString(length: n);
    return path;
  } finally {
    calloc.free(src);
    calloc.free(dst);
  }
}

int getModuleHandleNull() => _getModuleHandleW(nullptr);

bool wtsRegisterSessionNotification(int hwnd) =>
    _wtsRegisterSessionNotification(hwnd, notifyForThisSession) != 0;

bool wtsUnRegisterSessionNotification(int hwnd) =>
    _wtsUnRegisterSessionNotification(hwnd) != 0;

int registerSuspendResumeNotification(int hwnd) =>
    _registerSuspendResumeNotification(hwnd, deviceNotifyWindowHandle);

bool unregisterSuspendResumeNotification(int notify) =>
    _unregisterSuspendResumeNotification(notify) != 0;
