/// 手写 Win32 FFI 绑定（零第三方包装，保证 isolate 内可用）。
///
/// 覆盖前台焦点跟踪引擎所需的全部系统调用：
///  * SetWinEventHook / UnhookWinEvent         — EVENT_SYSTEM_FOREGROUND 事件订阅
///  * GetForegroundWindow / GetWindowThreadProcessId / IsWindowVisible / IsIconic
///  * OpenProcess / QueryFullProcessImageNameW — 前台进程真实镜像绝对路径
///  * GetLongPathNameW                          — 8.3 短路径展开
///  * CreateWindowExW + 消息泵                   — 消息专用窗口接收
///       WM_WTSSESSION_CHANGE（锁屏/解锁）与 WM_POWERBROADCAST（睡眠/唤醒）
///  * MsgWaitForMultipleObjectsEx               — 内核对象阻塞等待，0% CPU 空转
///  * CreateEventW / SetEvent                    — 主 isolate → watcher 的关机信号
///
/// 本文件必须保持纯 Dart（dart:ffi / package:ffi / dart:io），
/// 因为它运行在独立 watcher isolate 中，禁止依赖任何 Flutter 插件。
library;

import 'dart:ffi';

import 'package:ffi/ffi.dart';

// ─────────────────────────────────────────────────────────────
// 基础 Win32 类型别名
// ─────────────────────────────────────────────────────────────
typedef HWND = IntPtr;
typedef DWORD = Uint32;
typedef WORD = Uint16;
typedef LONG = Int32;
typedef BOOL = Int32;
typedef HANDLE = IntPtr;
typedef HHOOK = IntPtr;
typedef HMODULE = IntPtr;
typedef ATOM = Uint16;
typedef LRESULT = IntPtr;
typedef WPARAM = IntPtr;
typedef LPARAM = IntPtr;
typedef HPOWERNOTIFY = IntPtr;

// ─────────────────────────────────────────────────────────────
// 常量
// ─────────────────────────────────────────────────────────────
const int EVENT_SYSTEM_FOREGROUND = 0x0003;
const int WINEVENT_OUTOFCONTEXT = 0x0000;
const int WINEVENT_SKIPOWNPROCESS = 0x0002;

const int PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

const int QS_ALLINPUT = 0x04FF;
const int MWMO_INPUTAVAILABLE = 0x0002;

const int WAIT_OBJECT_0 = 0;
const int WAIT_TIMEOUT = 0x00000102;
const int WAIT_FAILED = 0xFFFFFFFF;

const int WM_DESTROY = 0x0002;
const int WM_QUIT = 0x0012;
const int WM_CLOSE = 0x0010;
const int WM_POWERBROADCAST = 0x0218;
const int PBT_APMSUSPEND = 0x0004;
const int PBT_APMRESUMEAUTOMATIC = 0x0012;
const int WM_WTSSESSION_CHANGE = 0x02B1;
const int WTS_SESSION_LOCK = 0x7;
const int WTS_SESSION_UNLOCK = 0x8;
const int NOTIFY_FOR_THIS_SESSION = 0;

/// CreateWindowExW 的 HWND_MESSAGE：消息专用窗口父句柄。
final int hwndMessage = -3;

const int DEVICE_NOTIFY_WINDOW_HANDLE = 0x00000000;

// ─────────────────────────────────────────────────────────────
// 结构体
// ─────────────────────────────────────────────────────────────

/// Win64 下 MSG 布局：8+4+4+8+8+4+(POINT 8)=48 字节。
final class Msg extends Struct {
  external HWND hwnd;
  @DWORD() external int message;
  @Uint32() external int _padding; // message 后对齐填充
  external WPARAM wParam;
  external LPARAM lParam;
  @DWORD() external int time;
  @Int32() external int ptX;
  @Int32() external int ptY;
  @Uint32() external int _tail; // 结构体 8 字节对齐尾部填充
}

final class WndClassExW extends Struct {
  @DWORD() external int cbSize;
  @DWORD() external int style;
  external Pointer<NativeFunction<LRESULT Function(HWND, DWORD, WPARAM, LPARAM)>>
      lpfnWndProc;
  @Int32() external int cbClsExtra;
  @Int32() external int cbWndExtra;
  external HMODULE hInstance;
  external IntPtr hIcon;
  external IntPtr hCursor;
  external IntPtr hbrBackground;
  external Pointer<Utf16> lpszMenuName;
  external Pointer<Utf16> lpszClassName;
  external IntPtr hIconSm;
}

/// GUID（电源通知等场景预留）。
final class Guid extends Struct {
  @Uint32() external int data1;
  @Uint16() external int data2;
  @Uint16() external int data3;
  @Array(8) external Array<Uint8> data4;
}

// ─────────────────────────────────────────────────────────────
// 函数指针签名（Native 与 Dart 两侧）
// ─────────────────────────────────────────────────────────────
typedef WinEventProcNative = Void Function(
    HHOOK, DWORD, HWND, LONG, LONG, DWORD, DWORD);
typedef WinEventProcDart = void Function(
    int, int, int, int, int, int, int);

// ─────────────────────────────────────────────────────────────
// 动态库导入
// ─────────────────────────────────────────────────────────────
final DynamicLibrary _user32 = DynamicLibrary.open('user32.dll');
final DynamicLibrary _kernel32 = DynamicLibrary.open('kernel32.dll');
final DynamicLibrary _wtsapi32 = DynamicLibrary.open('wtsapi32.dll');

// ─── user32 ──────────────────────────────────────────────────
final int Function(int, int, int, Pointer<NativeFunction<WinEventProcNative>>,
        int, int, int)
    _setWinEventHook = _user32
        .lookupFunction<
            IntPtr Function(Uint32, Uint32, HMODULE,
                Pointer<NativeFunction<WinEventProcNative>>, DWORD, DWORD, Uint32),
            int Function(int, int, int, Pointer<NativeFunction<WinEventProcNative>>,
                int, int, int)>('SetWinEventHook');

final BOOL Function(HHOOK) _unhookWinEvent = _user32
    .lookupFunction<BOOL Function(HHOOK), int Function(int)>('UnhookWinEvent');

final HWND Function() _getForegroundWindow = _user32
    .lookupFunction<HWND Function(), int Function()>('GetForegroundWindow');

final DWORD Function(HWND, Pointer<DWORD>) _getWindowThreadProcessId =
    _user32.lookupFunction<DWORD Function(HWND, Pointer<DWORD>),
        int Function(int, Pointer<DWORD>)>('GetWindowThreadProcessId');

final BOOL Function(HWND) _isWindowVisible = _user32
    .lookupFunction<BOOL Function(HWND), int Function(int)>('IsWindowVisible');

final BOOL Function(HWND) _isIconic = _user32
    .lookupFunction<BOOL Function(HWND), int Function(int)>('IsIconic');

final int Function(HWND, Pointer<Utf16>, int) _getWindowTextW = _user32
    .lookupFunction<
        int Function(HWND, Pointer<Utf16>, int),
        int Function(int, Pointer<Utf16>, int)>('GetWindowTextW');

final ATOM Function(Pointer<WndClassExW>) _registerClassExW = _user32.lookupFunction<
    ATOM Function(Pointer<WndClassExW>), int Function(
        Pointer<WndClassExW>)>('RegisterClassExW');

final HWND Function(DWORD, Pointer<Utf16>, Pointer<Utf16>, DWORD, int, int, int,
        int, HWND, IntPtr, HMODULE, IntPtr)
    _createWindowExW = _user32.lookupFunction<
        HWND Function(DWORD, Pointer<Utf16>, Pointer<Utf16>, DWORD, Int32, Int32,
            Int32, Int32, HWND, IntPtr, HMODULE, IntPtr),
        int Function(int, Pointer<Utf16>, Pointer<Utf16>, int, int, int, int,
            int, int, int, int, int)>('CreateWindowExW');

final BOOL Function(HWND) _destroyWindow = _user32
    .lookupFunction<BOOL Function(HWND), int Function(int)>('DestroyWindow');

final BOOL Function(Pointer<Utf16>, ATOM) _unregisterClassW = _user32.lookupFunction<
    BOOL Function(Pointer<Utf16>, ATOM), int Function(
        Pointer<Utf16>, int)>('UnregisterClassW');

final LRESULT Function(HWND, DWORD, WPARAM, LPARAM) _defWindowProcW = _user32
    .lookupFunction<LRESULT Function(HWND, DWORD, WPARAM, LPARAM),
        int Function(int, int, int, int)>('DefWindowProcW');

final DWORD Function(DWORD, Pointer<HANDLE>, DWORD, DWORD, DWORD)
    _msgWaitForMultipleObjectsEx = _user32.lookupFunction<
        DWORD Function(DWORD, Pointer<HANDLE>, DWORD, DWORD, DWORD),
        int Function(int, Pointer<HANDLE>, int, int, int)>(
            'MsgWaitForMultipleObjectsEx');

final BOOL Function(Pointer<Msg>, HWND, DWORD, DWORD, DWORD, DWORD) _getMessageW =
    _user32.lookupFunction<
        BOOL Function(Pointer<Msg>, HWND, DWORD, DWORD, DWORD, DWORD),
        int Function(Pointer<Msg>, int, int, int, int, int)>('GetMessageW');

final BOOL Function(Pointer<Msg>, HWND, DWORD, DWORD, DWORD) _peekMessageW =
    _user32.lookupFunction<
        BOOL Function(Pointer<Msg>, HWND, DWORD, DWORD, DWORD),
        int Function(Pointer<Msg>, int, int, int, int)>('PeekMessageW');

final BOOL Function(Pointer<Msg>) _translateMessage = _user32.lookupFunction<
    BOOL Function(Pointer<Msg>), int Function(Pointer<Msg>)>('TranslateMessage');

final LRESULT Function(Pointer<Msg>) _dispatchMessageW = _user32.lookupFunction<
    LRESULT Function(Pointer<Msg>), int Function(Pointer<Msg>)>('DispatchMessageW');

final HPOWERNOTIFY Function(HANDLE, DWORD) _registerSuspendResumeNotification =
    _user32.lookupFunction<
        HPOWERNOTIFY Function(HANDLE, DWORD),
        int Function(int, int)>('RegisterSuspendResumeNotification');

final BOOL Function(HPOWERNOTIFY) _unregisterSuspendResumeNotification = _user32
    .lookupFunction<BOOL Function(HPOWERNOTIFY), int Function(int)>(
        'UnregisterSuspendResumeNotification');

// ─── kernel32 ────────────────────────────────────────────────
final HANDLE Function(DWORD, BOOL, DWORD, Pointer<Utf16>) _createEventW =
    _kernel32.lookupFunction<
        HANDLE Function(DWORD, BOOL, DWORD, Pointer<Utf16>),
        int Function(int, int, int, Pointer<Utf16>)>('CreateEventW');

final BOOL Function(HANDLE) _setEvent = _kernel32
    .lookupFunction<BOOL Function(HANDLE), int Function(int)>('SetEvent');

final BOOL Function(HANDLE) _closeHandle = _kernel32
    .lookupFunction<BOOL Function(HANDLE), int Function(int)>('CloseHandle');

final HANDLE Function(DWORD, BOOL, DWORD) _openProcess = _kernel32.lookupFunction<
    HANDLE Function(DWORD, BOOL, DWORD), int Function(int, int, int)>(
        'OpenProcess');

final BOOL Function(HANDLE, DWORD, Pointer<Utf16>, Pointer<DWORD>)
    _queryFullProcessImageNameW = _kernel32.lookupFunction<
        BOOL Function(HANDLE, DWORD, Pointer<Utf16>, Pointer<DWORD>),
        int Function(int, int, Pointer<Utf16>, Pointer<DWORD>)>(
            'QueryFullProcessImageNameW');

final DWORD Function(Pointer<Utf16>, DWORD, Pointer<Utf16>, Pointer<DWORD>)
    _getLongPathNameW = _kernel32.lookupFunction<
        DWORD Function(Pointer<Utf16>, DWORD, Pointer<Utf16>, Pointer<DWORD>),
        int Function(Pointer<Utf16>, int, Pointer<Utf16>, Pointer<DWORD>)>(
            'GetLongPathNameW');

final HMODULE Function(Pointer<Utf16>) _getModuleHandleW = _kernel32.lookupFunction<
    HMODULE Function(Pointer<Utf16>), int Function(Pointer<Utf16>)>(
        'GetModuleHandleW');

// ─── wtsapi32 ────────────────────────────────────────────────
final BOOL Function(HWND, DWORD) _wtsRegisterSessionNotification = _wtsapi32
    .lookupFunction<BOOL Function(HWND, DWORD), int Function(int, int)>(
        'WTSRegisterSessionNotification');

final BOOL Function(HWND) _wtsUnRegisterSessionNotification = _wtsapi32
    .lookupFunction<BOOL Function(HWND), int Function(int)>(
        'WTSUnRegisterSessionNotification');

// ─────────────────────────────────────────────────────────────
// Dart 友好包装
// ─────────────────────────────────────────────────────────────

/// 订阅 EVENT_SYSTEM_FOREGROUND。返回 0 表示失败。
int setWinEventHook(Pointer<NativeFunction<WinEventProcNative>> proc) =>
    _setWinEventHook(EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, 0, proc,
        0, 0, WINEVENT_OUTOFCONTEXT | WINEVENT_SKIPOWNPROCESS);

bool unhookWinEvent(int hook) => _unhookWinEvent(hook) != 0;

int getForegroundWindow() => _getForegroundWindow();

/// 返回前台窗口所属进程 PID；失败返回 0。
int pidForWindow(int hwnd) {
  final pid = calloc<DWORD>();
  try {
    final r = _getWindowThreadProcessId(hwnd, pid);
    if (r == 0) return 0; // 窗口已销毁
    return pid.value;
  } finally {
    calloc.free(pid);
  }
}

bool isWindowVisible(int hwnd) => _isWindowVisible(hwnd) != 0;
bool isIconic(int hwnd) => _isIconic(hwnd) != 0;

String windowText(int hwnd) {
  final buf = calloc<Utf16>(512);
  try {
    final n = _getWindowTextW(hwnd, buf, 512);
    if (n <= 0) return '';
    return buf.toDartString(length: n);
  } finally {
    calloc.free(buf);
  }
}

/// 调用方保证 arena 生命周期覆盖窗口存在期间。
int registerWatcherWindowClass(
    Pointer<WndClassExW> wc, String className, int hInstance,
    Pointer<NativeFunction<LRESULT Function(HWND, DWORD, WPARAM, LPARAM)>> proc) {
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

/// 创建消息专用窗口（父窗口 = HWND_MESSAGE，不可见、不参与 z-order）。
int createMessageOnlyWindow(String className, int hInstance) {
  final cls = className.toNativeUtf16();
  final title = 'BlackOhmWatcher'.toNativeUtf16();
  try {
    return _createWindowExW(0, cls, title, 0, 0, 0, 0, 0, hwndMessage, 0,
        hInstance, 0);
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

/// 阻塞等待：[handles] 任一被信号量唤醒（WAIT_OBJECT_0..n-1），
/// 或有输入消息到达（WAIT_OBJECT_0+n），或 [ms] 超时（WAIT_TIMEOUT）。
int msgWaitForMultipleObjectsEx(List<int> handles, int ms) {
  if (handles.isEmpty) {
    return _msgWaitForMultipleObjectsEx(
        0, nullptr.cast(), ms, QS_ALLINPUT, MWMO_INPUTAVAILABLE);
  }
  final arr = calloc<HANDLE>(handles.length);
  for (var i = 0; i < handles.length; i++) {
    arr[i] = handles[i];
  }
  try {
    return _msgWaitForMultipleObjectsEx(handles.length, arr, ms, QS_ALLINPUT,
        MWMO_INPUTAVAILABLE);
  } finally {
    calloc.free(arr);
  }
}

/// 排空当前线程消息队列；返回 false 表示收到 WM_QUIT。
bool pumpMessages(Pointer<Msg> msg) {
  const pmRemove = 1; // PM_REMOVE
  while (_peekMessageW(msg, 0, 0, 0, pmRemove) != 0) {
    if (msg.ref.message == WM_QUIT) return false;
    _translateMessage(msg);
    _dispatchMessageW(msg);
  }
  return true;
}

/// 创建手动复位事件内核对象，用于跨 isolate 关机信号。
int createShutdownEvent() => _createEventW(0, 1, 0, nullptr);

bool setEvent(int handle) => _setEvent(handle) != 0;
bool closeHandle(int handle) => _closeHandle(handle) != 0;

/// 打开进程（PROCESS_QUERY_LIMITED_INFORMATION）；失败返回 0（如提权进程）。
int openProcessQuery(int pid) =>
    _openProcess(PROCESS_QUERY_LIMITED_INFORMATION, 0, pid);

/// 获取进程真实镜像绝对路径（Win32 形态）；失败返回 null。
String? queryProcessImagePath(int processHandle) {
  final buf = calloc<Utf16>(1024);
  final size = calloc<DWORD>();
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

/// 展开 8.3 短路径；失败原样返回。
String getLongPathName(String path) {
  if (!path.contains('~')) return path;
  final src = path.toNativeUtf16();
  final dst = calloc<Utf16>(1024);
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
    _wtsRegisterSessionNotification(hwnd, NOTIFY_FOR_THIS_SESSION) != 0;

bool wtsUnRegisterSessionNotification(int hwnd) =>
    _wtsUnRegisterSessionNotification(hwnd) != 0;

int registerSuspendResumeNotification(int hwnd) =>
    _registerSuspendResumeNotification(hwnd, DEVICE_NOTIFY_WINDOW_HANDLE);

bool unregisterSuspendResumeNotification(int notify) =>
    _unregisterSuspendResumeNotification(notify) != 0;
