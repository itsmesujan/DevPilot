import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  late final FlutterSecureStorage _secure;
  late SharedPreferences _prefs;

  static const _keyOpenAI = 'key_openai';
  static const _keyAnthropic = 'key_anthropic';
  static const _keyGemini = 'key_gemini';
  static const _keyMistral = 'key_mistral';
  static const _keyDeepSeek = 'key_deepseek';
  static const _keyGroq = 'key_groq';
  static const _keyTogether = 'key_together';
  static const _keyKimi = 'key_kimi';
  static const _keyOpenRouter = 'key_openrouter';
  static const _keyOllama = 'key_ollama_url';

  Future<void> init() async {
    const androidOptions = AndroidOptions(encryptedSharedPreferences: true);
    _secure = const FlutterSecureStorage(aOptions: androidOptions);
    _prefs = await SharedPreferences.getInstance();
  }

  // ── API Keys (Keychain/Keystore) ──────────────────────────────────────────
  Future<void> saveApiKey(String provider, String key) =>
      _secure.write(key: 'key_$provider', value: key);

  Future<String?> getApiKey(String provider) =>
      _secure.read(key: 'key_$provider');

  Future<void> deleteApiKey(String provider) =>
      _secure.delete(key: 'key_$provider');

  // Convenience getters
  Future<String?> get openaiKey => _secure.read(key: _keyOpenAI);
  Future<String?> get anthropicKey => _secure.read(key: _keyAnthropic);
  Future<String?> get geminiKey => _secure.read(key: _keyGemini);
  Future<String?> get mistralKey => _secure.read(key: _keyMistral);
  Future<String?> get deepseekKey => _secure.read(key: _keyDeepSeek);
  Future<String?> get groqKey => _secure.read(key: _keyGroq);
  Future<String?> get togetherKey => _secure.read(key: _keyTogether);
  Future<String?> get kimiKey => _secure.read(key: _keyKimi);
  Future<String?> get openrouterKey => _secure.read(key: _keyOpenRouter);
  Future<String?> get ollamaUrl => _secure.read(key: _keyOllama);

  // ── Preferences ──────────────────────────────────────────────────────────
  String get selectedModelId => _prefs.getString('selected_model') ?? 'gpt-5.4-mini';
  Future<void> setSelectedModel(String id) => _prefs.setString('selected_model', id);

  String get selectedProvider => _prefs.getString('selected_provider') ?? 'openai';
  Future<void> setSelectedProvider(String p) => _prefs.setString('selected_provider', p);

  bool get darkMode => _prefs.getBool('dark_mode') ?? true;
  Future<void> setDarkMode(bool v) => _prefs.setBool('dark_mode', v);

  bool get voiceEnabled => _prefs.getBool('voice_enabled') ?? false;
  Future<void> setVoiceEnabled(bool v) => _prefs.setBool('voice_enabled', v);

  int get maxContextTokens => _prefs.getInt('max_context_tokens') ?? 4096;
  Future<void> setMaxContextTokens(int v) => _prefs.setInt('max_context_tokens', v);

  double get temperature => (_prefs.getDouble('temperature') ?? 0.7);
  Future<void> setTemperature(double v) => _prefs.setDouble('temperature', v);

  bool get streamingEnabled => _prefs.getBool('streaming') ?? true;
  Future<void> setStreaming(bool v) => _prefs.setBool('streaming', v);

  String get systemPrompt => _prefs.getString('system_prompt') ?? 
      'You are DevPilot, an advanced AI assistant running on the user\'s device. '
      'Be concise, precise, and helpful. You can run tools, browse the web, and remember past conversations.';
  Future<void> setSystemPrompt(String v) => _prefs.setString('system_prompt', v);

  // ── Downloaded Models ──────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getDownloadedModels() async {
    final str = _prefs.getString('downloaded_models');
    if (str == null) return [];
    try {
      final list = jsonDecode(str) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setDownloadedModels(List<Map<String, dynamic>> models) =>
      _prefs.setString('downloaded_models', jsonEncode(models));

  // ── HuggingFace Token ──────────────────────────────────────────────────────
  static const _keyHFToken = 'key_huggingface';
  Future<String?> get hfToken => _secure.read(key: _keyHFToken);
  Future<void> setHFToken(String token) => _secure.write(key: _keyHFToken, value: token);
  Future<void> deleteHFToken() => _secure.delete(key: _keyHFToken);

  // ── Study Mode Settings ────────────────────────────────────────────────────
  int get pomodoroMinutes => _prefs.getInt('pomodoro_minutes') ?? 25;
  Future<void> setPomodoroMinutes(int v) => _prefs.setInt('pomodoro_minutes', v);

  int get pomodoroBreakMinutes => _prefs.getInt('pomodoro_break_minutes') ?? 5;
  Future<void> setPomodoroBreakMinutes(int v) => _prefs.setInt('pomodoro_break_minutes', v);

  bool get studyReminders => _prefs.getBool('study_reminders') ?? true;
  Future<void> setStudyReminders(bool v) => _prefs.setBool('study_reminders', v);
}
