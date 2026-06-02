import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../storage/storage_service.dart';
import '../../models/model_profile.dart';
import '../storage/app_database.dart';

class DownloadProgress {
  final String modelId;
  final double progress;
  final int receivedBytes;
  final int totalBytes;
  final bool isComplete;
  final String? error;

  const DownloadProgress({
    required this.modelId,
    required this.progress,
    required this.receivedBytes,
    required this.totalBytes,
    this.isComplete = false,
    this.error,
  });
}

class DownloadManager {
  DownloadManager._();
  static final DownloadManager instance = DownloadManager._();

  final _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  Stream<DownloadProgress> downloadModel({
    required String modelId,
    required String url,
    required String filename,
    required int estimatedSizeMb,
    ModelProfile? customProfile,
  }) {
    final controller = StreamController<DownloadProgress>();

    () async {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final modelsDir = Directory(p.join(dir.path, 'models'));
        if (!modelsDir.existsSync()) modelsDir.createSync(recursive: true);

        final destPath = p.join(modelsDir.path, filename);
        final cancelToken = CancelToken();
        _cancelTokens[modelId] = cancelToken;

        int startByte = 0;
        final destFile = File(destPath);
        if (destFile.existsSync()) {
          startByte = destFile.lengthSync();
        }

        String resolvedUrl = url;
        final hfToken = await StorageService.instance.hfToken;
        final headers = <String, String>{
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };
        if (hfToken != null && hfToken.isNotEmpty && url.contains('huggingface.co')) {
          headers['Authorization'] = 'Bearer $hfToken';
        }

        // Manual redirect resolution to extract direct S3/CDN URL and clean headers
        try {
          var currentUrl = url;
          var currentHeaders = Map<String, String>.from(headers);
          final client = HttpClient();
          client.connectionTimeout = const Duration(seconds: 15);

          for (int i = 0; i < 5; i++) {
            final uri = Uri.parse(currentUrl);
            final request = await client.getUrl(uri);

            currentHeaders.forEach((key, val) {
              request.headers.set(key, val);
            });
            request.followRedirects = false;

            final response = await request.close();
            if (response.statusCode >= 300 && response.statusCode < 400) {
              final location = response.headers.value(HttpHeaders.locationHeader);
              if (location != null) {
                final nextUri = uri.resolve(location);
                currentUrl = nextUri.toString();

                // Strip Authorization when redirecting away from huggingface.co
                if (!currentUrl.contains('huggingface.co')) {
                  currentHeaders.remove(HttpHeaders.authorizationHeader);
                }
                continue;
              }
            }
            break;
          }
          client.close();
          resolvedUrl = currentUrl;
        } catch (_) {
          // Fallback to original URL
        }

        final downloadHeaders = <String, String>{
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        };
        if (hfToken != null && hfToken.isNotEmpty && resolvedUrl.contains('huggingface.co')) {
          downloadHeaders['Authorization'] = 'Bearer $hfToken';
        }
        if (startByte > 0) {
          downloadHeaders['Range'] = 'bytes=$startByte-';
        }

        await _dio.download(
          resolvedUrl,
          destPath,
          cancelToken: cancelToken,
          options: Options(
            headers: downloadHeaders,
            responseType: ResponseType.stream,
            followRedirects: true,
          ),
          onReceiveProgress: (received, total) {
            final totalBytes =
                total > 0 ? total + startByte : estimatedSizeMb * 1024 * 1024;
            final receivedTotal = received + startByte;
            controller.add(DownloadProgress(
              modelId: modelId,
              progress: totalBytes > 0 ? receivedTotal / totalBytes : 0,
              receivedBytes: receivedTotal,
              totalBytes: totalBytes,
            ));
          },
        );

        AppDatabase.instance.upsertDownload(
          modelId: modelId,
          filename: filename,
          path: destPath,
          sizeMb: estimatedSizeMb,
        );

        if (customProfile != null) {
          AppDatabase.instance.insertMemory(
            id: 'custom_${customProfile.id}',
            content: jsonEncode(customProfile.toJson()),
            type: 'custom_model_profile',
            createdAt: DateTime.now().toIso8601String(),
          );
        }


        controller.add(DownloadProgress(
          modelId: modelId,
          progress: 1.0,
          receivedBytes: estimatedSizeMb * 1024 * 1024,
          totalBytes: estimatedSizeMb * 1024 * 1024,
          isComplete: true,
        ));
      } catch (e) {
        if (e is DioException && CancelToken.isCancel(e)) {
          controller.add(DownloadProgress(
            modelId: modelId,
            progress: 0,
            receivedBytes: 0,
            totalBytes: 0,
            error: 'Cancelled',
          ));
        } else {
          controller.add(DownloadProgress(
            modelId: modelId,
            progress: 0,
            receivedBytes: 0,
            totalBytes: 0,
            error: e.toString(),
          ));
        }
      } finally {
        _cancelTokens.remove(modelId);
        await controller.close();
      }
    }();

    return controller.stream;
  }

  void cancelDownload(String modelId) {
    _cancelTokens[modelId]?.cancel('User cancelled');
    _cancelTokens.remove(modelId);
  }

  Future<void> deleteModel(String modelId, String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'models', filename));
    if (file.existsSync()) file.deleteSync();
    AppDatabase.instance.deleteDownload(modelId);
    AppDatabase.instance.deleteMemory('custom_$modelId');
  }

  bool isModelDownloaded(String modelId) {
    return AppDatabase.instance.isDownloaded(modelId);
  }
}