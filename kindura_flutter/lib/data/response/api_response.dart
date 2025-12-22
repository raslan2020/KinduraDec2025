import 'package:kindura_ai/data/response/status.dart';

class ApiResponse<T> {
  Status? status;
  T? data;
  String? message;

  ApiResponse(this.status, this.data, this.message);

  ApiResponse.loading() : status = Status.LOADING;
  ApiResponse.completed(this.data) : status = Status.COMPLETED;
  ApiResponse.error(this.message) : status = Status.ERROR;

  // Add when method for pattern matching
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) error,
    required R Function() loading,
  }) {
    switch (status) {
      case Status.COMPLETED:
        // Allow null data for void responses (like delete operations)
        return success(data as T);
      case Status.ERROR:
        return error(message ?? 'Unknown error');
      case Status.LOADING:
        return loading();
      default:
        return error('Unknown status');
    }
  }

  @override
  String toString() {
    return "Status: $status \n Message: $message \n Data: $data";
  }
}
