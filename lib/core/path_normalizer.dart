/// 进程镜像路径标准化。
///
/// 运行期捕获（QueryFullProcessImageNameW）与入库登记（拖拽扫描）两侧
/// 都必须经过同一套标准化，才能稳定匹配：
///  * 统一反斜杠、去除尾部分隔符
///  * 去除 `\\?\` / `\\.\` 设备路径前缀
///  * 8.3 短路径展开（含 `~` 的段）在 watcher isolate 内先经 GetLongPathNameW
///  * 符号链接解析在入库时经 File.resolveSymbolicLinksAsync 完成
///  * 全部小写化（Windows 内核路径不区分大小写）
library;

String normalizeExePath(String path) {
  var p = path.trim();
  if (p.startsWith(r'\\?\UNC\')) {
    p = p.substring(6); // \\?\UNC\server\share → \\server\share... 保留 UNC 形态
    p = r'\\' + p;
  } else if (p.startsWith(r'\\?\')) {
    p = p.substring(4);
  } else if (p.startsWith(r'\\.\')) {
    p = p.substring(4);
  }
  p = p.replaceAll('/', r'\');
  while (p.endsWith(r'\')) {
    p = p.substring(0, p.length - 1);
  }
  return p.toLowerCase();
}

/// 非破坏性展示用路径（保留原大小写）。
String displayPath(String path) {
  var p = path;
  if (p.startsWith(r'\\?\')) p = p.substring(4);
  return p;
}
