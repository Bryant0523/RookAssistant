import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../../core/models/intent.dart';

class FilesModule {
  static final FilesModule instance = FilesModule._();
  FilesModule._();

  List<String> get supportedIntents =>
    ['organize_files', 'search_file', 'list_files', 'move_file'];

  bool canHandle(String intent) => supportedIntents.contains(intent);

  Future<String> execute(JarvisIntent intent) async {
    switch (intent.name) {
      case 'list_files':     return _listFiles();
      case 'search_file':    return _searchFile(intent.params['query'] as String? ?? '');
      case 'organize_files': return _organizeFiles();
      default:               return 'Comando de archivos no reconocido.';
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        final manage = await Permission.manageExternalStorage.request();
        return manage.isGranted;
      }
      return status.isGranted;
    }
    return true; // iOS maneja permisos por directorio
  }

  Future<String> _listFiles() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        return 'Necesito permiso de almacenamiento para acceder a tus archivos.';
      }

      final dir = await getExternalStorageDirectory() ??
                  await getApplicationDocumentsDirectory();

      final entities = dir.listSync(recursive: false);
      final files = entities
        .whereType<File>()
        .map((f) => f.path.split('/').last)
        .take(8)
        .toList();

      if (files.isEmpty) return 'No encontré archivos en tu almacenamiento principal.';
      return 'Encontré ${files.length} archivos. Los primeros son: ${files.join(", ")}.';
    } catch (e) {
      debugPrint('[Files] Error al listar: $e');
      return 'Hubo un error al acceder a tus archivos.';
    }
  }

  Future<String> _searchFile(String query) async {
    if (query.isEmpty) return 'Dime el nombre del archivo que buscas.';

    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        return 'Necesito permiso de almacenamiento para buscar archivos.';
      }

      final dir = await getExternalStorageDirectory() ??
                  await getApplicationDocumentsDirectory();

      final results = <String>[];
      _searchRecursive(dir, query.toLowerCase(), results);

      if (results.isEmpty) {
        return 'No encontré ningún archivo con "$query".';
      }

      return 'Encontré ${results.length} archivo${results.length > 1 ? "s" : ""} con "$query": ${results.take(3).join(", ")}.';
    } catch (e) {
      debugPrint('[Files] Error al buscar: $e');
      return 'Hubo un error al buscar el archivo.';
    }
  }

  void _searchRecursive(Directory dir, String query, List<String> results) {
    try {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final name = entity.path.split('/').last.toLowerCase();
          if (name.contains(query)) results.add(entity.path.split('/').last);
        } else if (entity is Directory && results.length < 20) {
          _searchRecursive(entity, query, results);
        }
      }
    } catch (_) {}
  }

  Future<String> _organizeFiles() async {
    try {
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        return 'Necesito permiso de almacenamiento para organizar archivos.';
      }

      final dir = await getExternalStorageDirectory() ??
                  await getApplicationDocumentsDirectory();

      int moved = 0;
      final categories = {
        'Imágenes' : ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic'],
        'Videos'   : ['.mp4', '.mov', '.avi', '.mkv', '.m4v'],
        'Documentos': ['.pdf', '.doc', '.docx', '.txt', '.xlsx', '.pptx'],
        'Música'   : ['.mp3', '.m4a', '.flac', '.wav', '.ogg'],
        'Otros'    : [],
      };

      for (final entity in dir.listSync()) {
        if (entity is! File) continue;
        final ext = entity.path.toLowerCase().split('.').last;
        String targetFolder = 'Otros';

        for (final entry in categories.entries) {
          if (entry.value.any((e) => e == '.$ext')) {
            targetFolder = entry.key;
            break;
          }
        }

        final targetDir = Directory('${dir.path}/$targetFolder');
        if (!targetDir.existsSync()) targetDir.createSync();

        final fileName = entity.path.split('/').last;
        await entity.rename('${targetDir.path}/$fileName');
        moved++;
      }

      if (moved == 0) return 'Los archivos ya están organizados.';
      return 'Listo. Organicé $moved archivo${moved > 1 ? "s" : ""} por tipo.';
    } catch (e) {
      debugPrint('[Files] Error al organizar: $e');
      return 'Hubo un error al organizar los archivos.';
    }
  }
}
