import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../models/character.dart';
import '../services/character_service.dart';

class CharacterProvider extends ChangeNotifier {
  final CharacterService _characterService;
  final int childProfileId; // ✨ 1. 필수 파라미터로 추가

  CharacterProvider({
    required CharacterService characterService,
    required this.childProfileId, // ✨ 2. 생성자에서 받도록 수정
  }) : _characterService = characterService;

  List<Character> _characters = const [];

  bool _isLoading = true;
  String? _loadError;
  bool _isCreating = false;
  String? _createError;
  bool _disposed = false;

  List<Character> get characters => _characters;
  bool get isLoading => _isLoading;
  String? get loadError => _loadError;
  bool get isEmpty => !_isLoading && _loadError == null && _characters.isEmpty;
  bool get isCreating => _isCreating;
  String? get createError => _createError;

  Future<void> load() async {
    _isLoading = true;
    _loadError = null;
    _safeNotify();

    try {
      // ✨ 3. 서비스 호출 시 childProfileId 넘겨주기
      _characters = await _characterService.fetchCharacters(childProfileId);
    } on ApiException catch (error) {
      _loadError = error.message;
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  Future<Character?> create({
    required String name,
    required String personality,
    required String description,
    required String type,
  }) async {
    _isCreating = true;
    _createError = null;
    _safeNotify();

    try {
      final character = await _characterService.createCharacter(
        childProfileId: childProfileId, // ✨ 4. 서비스 호출 시 childProfileId 넘겨주기
        name: name,
        personality: personality,
        description: description,
        type: type,
      );
      _characters = [character, ..._characters];
      return character;
    } on ApiException catch (error) {
      _createError = error.message;
      return null;
    } finally {
      _isCreating = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
