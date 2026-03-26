class ApiResponse<T> {
  final bool ok;
  final T? data;
  final String message;
  final int statusCode;
  final dynamic raw;

  const ApiResponse({
    required this.ok,
    required this.message,
    required this.statusCode,
    this.data,
    this.raw,
  });

  /// ✅ Success helper
  factory ApiResponse.success(T? data, {int statusCode = 200, String message = 'OK'}) {
    return ApiResponse<T>(
      ok: true,
      data: data,
      message: message,
      statusCode: statusCode,
      raw: data,
    );
  }

  /// ✅ Failure helper (remplace les anciens .failure() / .ok param etc.)
  factory ApiResponse.failure({required String message, int statusCode = 0, dynamic raw}) {
    return ApiResponse<T>(
      ok: false,
      data: null,
      message: message,
      statusCode: statusCode,
      raw: raw,
    );
  }
}
