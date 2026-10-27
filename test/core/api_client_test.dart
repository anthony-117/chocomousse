import 'package:chocomousse/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _error(DioExceptionType type, {int? status}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: type,
    response: status == null ? null : Response<void>(requestOptions: options, statusCode: status),
  );
}

void main() {
  test('describeApiError gives a short message per failure kind', () {
    expect(describeApiError(_error(DioExceptionType.connectionError)), 'Cannot reach the TravelGenie server.');
    expect(describeApiError(_error(DioExceptionType.connectionTimeout)), 'Cannot reach the TravelGenie server.');
    expect(describeApiError(_error(DioExceptionType.receiveTimeout)), 'The server took too long to answer.');
    expect(describeApiError(_error(DioExceptionType.badResponse, status: 404)), 'Not found.');
    expect(
      describeApiError(_error(DioExceptionType.badResponse, status: 500)),
      'The server could not handle this request.',
    );
    expect(describeApiError(_error(DioExceptionType.cancel)), 'Something went wrong. Please try again.');
    expect(describeApiError(StateError('x')), 'Something went wrong. Please try again.');
  });
}
