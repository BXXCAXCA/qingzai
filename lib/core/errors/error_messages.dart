import 'app_exception.dart';

class ErrorMessageFormatter {
  const ErrorMessageFormatter();

  String format(Object error) {
    if (error is ValidationException) {
      return '输入内容不符合要求：${error.message}';
    }
    if (error is StorageException) {
      return '本地存储遇到问题，请检查设备空间后重试。';
    }
    if (error is WebDavException) {
      return 'WebDAV 连接失败，请检查服务器地址、账号密码或网络连接。';
    }
    if (error is AuthenticationException) {
      return '解密失败，请确认主密码是否正确。';
    }
    if (error is SyncException) {
      return '同步失败，变更已保留在本地，可稍后重试。';
    }
    if (error is TransferException) {
      return '局域网传输失败，请确认双方在同一网络并重新尝试。';
    }
    if (error is UpdateException) {
      return '更新检查或下载失败，请稍后重试。';
    }

    return '发生未知错误，请稍后重试。';
  }
}
