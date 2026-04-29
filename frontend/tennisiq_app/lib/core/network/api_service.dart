import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  final void Function()? onUnauthenticated;

  ApiService({this.onUnauthenticated})
      : _dio = Dio(BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
          headers: {'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Exclude refresh and login endpoints from getting the generic bear auth token injected normally if deemed necessary
          if (!options.path.contains('/auth/login') && !options.path.contains('/auth/register')) {
            final token = await _secureStorage.read(key: 'access_token');
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 && !e.requestOptions.path.contains(ApiConstants.refresh)) {
            // Attempt to refresh the token
            final refreshToken = await _secureStorage.read(key: 'refresh_token');
            if (refreshToken != null) {
              try {
                final refreshResponse = await _dio.post(
                  ApiConstants.refresh,
                  data: {'refresh': refreshToken},
                );

                final newAccessToken = refreshResponse.data['access'];
                await _secureStorage.write(key: 'access_token', value: newAccessToken);

                // Retry original request
                final opts = Options(
                  method: e.requestOptions.method,
                  headers: e.requestOptions.headers,
                );
                opts.headers?['Authorization'] = 'Bearer $newAccessToken';
                
                final retryResponse = await _dio.request(
                  e.requestOptions.path,
                  options: opts,
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                );
                return handler.resolve(retryResponse);
              } catch (refreshError) {
                // Refresh failed, logout user logically
                await _secureStorage.deleteAll();
                if (onUnauthenticated != null) {
                  onUnauthenticated!();
                }
                return handler.next(e);
              }
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get client => _dio;
}
