/// 用户连接状态服务
class UserConnectionStateService {
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;

  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;

  void resetConnectionState() {
    _isConnected = true;
    _isReconnecting = false;
    _lastError = null;
  }

  void setReconnecting(bool reconnecting) {
    _isReconnecting = reconnecting;
  }

  void markConnected() {
    _isConnected = true;
    _lastError = null;
  }

  void markDisconnected(String error) {
    _isConnected = false;
    _lastError = error;
  }
}
