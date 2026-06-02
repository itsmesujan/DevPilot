import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://huggingface.co/second-state/All-MiniLM-L6-v2-Embedding-GGUF/resolve/main/all-MiniLM-L6-v2-Q4_K_M.gguf';
  final dir = Directory('assets/models');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  
  final file = File('assets/models/all-MiniLM-L6-v2-Q4_K_M.gguf');
  if (file.existsSync()) {
    print('MiniLM already exists at ${file.path}');
    return;
  }
  
  print('Downloading MiniLM (22MB) from $url...');
  final request = http.Request('GET', Uri.parse(url));
  final response = await request.send();
  
  if (response.statusCode != 200) {
    print('Failed to download: ${response.statusCode}');
    exit(1);
  }
  
  final out = file.openWrite();
  int total = response.contentLength ?? 0;
  int downloaded = 0;
  int lastPercent = -1;
  
  await for (final chunk in response.stream) {
    out.add(chunk);
    downloaded += chunk.length;
    if (total > 0) {
      final percent = (downloaded * 100 ~/ total);
      if (percent != lastPercent && percent % 10 == 0) {
        print('Downloaded $percent% ($downloaded / $total bytes)');
        lastPercent = percent;
      }
    }
  }
  
  await out.close();
  print('Successfully saved MiniLM to ${file.path}');
}
