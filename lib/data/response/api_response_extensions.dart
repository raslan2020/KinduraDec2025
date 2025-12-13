import 'package:kindura_ai/data/response/api_response.dart';
import 'package:kindura_ai/data/response/status.dart';

extension ApiResponseExtensions<T> on ApiResponse<T> {
  /// Provides a `when` method for pattern matching on ApiResponse states
  R when<R>({
    required R Function(T data) success,
    required R Function(String error) error,
    R Function()? loading,
  }) {
    switch (status) {
      case Status.COMPLETED:
        if (data != null) {
          return success(data!);
        } else {
          return error('No data available');
        }
      case Status.ERROR:
        return error(message ?? 'Unknown error');
      case Status.LOADING:
        return loading?.call() ?? success(data!);
      default:
        return error('Unknown status');
    }
  }

  /// Returns true if the response is successful
  bool get isSuccess => status == Status.COMPLETED && data != null;

  /// Returns true if the response has an error
  bool get isError => status == Status.ERROR;

  /// Returns true if the response is loading
  bool get isLoading => status == Status.LOADING;
}