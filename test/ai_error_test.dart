import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:catodo/services/ai_service.dart';

void main() {
  RequestOptions reqs() => RequestOptions(path: '/');

  Response<dynamic> resp(int status, [dynamic body]) {
    return Response<dynamic>(
      requestOptions: reqs(),
      statusCode: status,
      data: body,
    );
  }

  group('mapDioExceptionForTest 状态码映射', () {
    test('401 → unauthorized', () {
      final e = DioException(
        requestOptions: reqs(),
        response: resp(401, {
          'error': {'message': 'invalid api key'}
        }),
      );
      final err = mapDioExceptionForTest(e);
      expect(err.type, AiErrorType.unauthorized);
      expect(err.statusCode, 401);
      expect(err.detail, contains('invalid api key'));
    });

    test('403 → forbidden', () {
      final e = DioException(requestOptions: reqs(), response: resp(403));
      expect(mapDioExceptionForTest(e).type, AiErrorType.forbidden);
    });

    test('404 → notFound', () {
      final e = DioException(
        requestOptions: reqs(),
        response: resp(404, {
          'error': {'message': 'model not found'}
        }),
      );
      final err = mapDioExceptionForTest(e);
      expect(err.type, AiErrorType.notFound);
      expect(err.detail, contains('model not found'));
    });

    test('400 → badRequest', () {
      final e = DioException(requestOptions: reqs(), response: resp(400));
      expect(mapDioExceptionForTest(e).type, AiErrorType.badRequest);
    });

    test('429 → rateLimited', () {
      final e = DioException(requestOptions: reqs(), response: resp(429));
      expect(mapDioExceptionForTest(e).type, AiErrorType.rateLimited);
    });

    test('500/502/503 → serverError', () {
      for (final s in [500, 502, 503]) {
        final e = DioException(requestOptions: reqs(), response: resp(s));
        expect(mapDioExceptionForTest(e).type, AiErrorType.serverError,
            reason: 'status $s');
      }
    });
  });

  group('mapDioExceptionForTest 类型映射（无 status code）', () {
    test('connectionTimeout → timeout', () {
      final e = DioException(
        requestOptions: reqs(),
        type: DioExceptionType.connectionTimeout,
      );
      expect(mapDioExceptionForTest(e).type, AiErrorType.timeout);
    });

    test('sendTimeout / receiveTimeout → timeout', () {
      for (final t in [
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final e = DioException(requestOptions: reqs(), type: t);
        expect(mapDioExceptionForTest(e).type, AiErrorType.timeout,
            reason: '$t');
      }
    });

    test('connectionError → network', () {
      final e = DioException(
        requestOptions: reqs(),
        type: DioExceptionType.connectionError,
      );
      expect(mapDioExceptionForTest(e).type, AiErrorType.network);
    });

    test('badCertificate → network', () {
      final e = DioException(
        requestOptions: reqs(),
        type: DioExceptionType.badCertificate,
      );
      expect(mapDioExceptionForTest(e).type, AiErrorType.network);
    });

    test('其它 unknown', () {
      final e = DioException(
        requestOptions: reqs(),
        type: DioExceptionType.cancel,
      );
      expect(mapDioExceptionForTest(e).type, AiErrorType.unknown);
    });
  });

  group('AiCallError 基本属性', () {
    test('detail 截断超过 240 字符', () {
      final long = 'x' * 500;
      final e = DioException(requestOptions: reqs(), response: resp(401, long));
      final err = mapDioExceptionForTest(e);
      // 240 字符上限 + 1 个 …
      expect(err.detail!.length, lessThanOrEqualTo(240));
      expect(err.detail!.endsWith('…'), isTrue);
    });

    test('toString 含状态码与类型', () {
      const err = AiCallError(
        type: AiErrorType.unauthorized,
        message: 'k',
        statusCode: 401,
      );
      final s = err.toString();
      expect(s, contains('unauthorized'));
      expect(s, contains('401'));
    });
  });
}
