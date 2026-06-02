import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../models/skill_models.dart';

class SkillManager {
  SkillManager._();
  static final SkillManager instance = SkillManager._();

  final List<Skill> _skills = [];
  List<Skill> get skills => List.unmodifiable(_skills);

  Future<void> initialize() async {
    _skills.clear();
    final dir = await _getSkillsDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      // Create some default skills
      await saveSkill(Skill(
        name: 'Code Reviewer',
        description: 'Analyzes code for bugs, style, and performance issues.',
        systemPrompt: 'You are an expert Code Reviewer. Analyze the provided code, pointing out potential bugs, code smells, and performance issues. Always suggest clear, concise improvements.',
        allowedTools: ['read_file', 'dart_analyze', 'flutter_test'],
      ));
      await saveSkill(Skill(
        name: 'Research Analyst',
        description: 'Gathers information from the web and summarizes findings.',
        systemPrompt: 'You are a Research Analyst. Your goal is to gather accurate information using your search tools, synthesize it, and provide a comprehensive, well-structured report with citations.',
        allowedTools: ['web_search', 'url_reader'],
      ));
    } else {
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content);
            _skills.add(Skill.fromJson(json));
          } catch (e) {
            // Ignore corrupted skill files
          }
        }
      }
    }
  }

  Future<Directory> _getSkillsDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(docDir.path, 'skills'));
  }

  Future<void> saveSkill(Skill skill) async {
    final dir = await _getSkillsDirectory();
    final file = File(p.join(dir.path, '${skill.id}.json'));
    await file.writeAsString(jsonEncode(skill.toJson()));
    
    final existingIndex = _skills.indexWhere((s) => s.id == skill.id);
    if (existingIndex >= 0) {
      _skills[existingIndex] = skill;
    } else {
      _skills.add(skill);
    }
  }

  Future<void> deleteSkill(String id) async {
    final dir = await _getSkillsDirectory();
    final file = File(p.join(dir.path, '$id.json'));
    if (await file.exists()) {
      await file.delete();
    }
    _skills.removeWhere((s) => s.id == id);
  }
}
