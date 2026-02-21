import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/base_url_manager.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';

class ServerSettingsPage extends ConsumerStatefulWidget {
  const ServerSettingsPage({super.key});

  @override
  ConsumerState<ServerSettingsPage> createState() => _ServerSettingsPageState();
}

class _ServerSettingsPageState extends ConsumerState<ServerSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8000');
  bool _isLoading = false;
  String? _currentServerUrl;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  Future<void> _loadCurrentSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final urlManager = BaseUrlManager();
    await urlManager.init(prefs);
    
    final savedUrl = urlManager.getSavedServerUrl();
    setState(() {
      _currentServerUrl = savedUrl ?? 'http://lepm.local:8000';
    });

    // Парсим текущий URL для заполнения полей
    if (savedUrl != null && savedUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(savedUrl);
        _ipController.text = uri.host;
        _portController.text = uri.port.toString();
      } catch (e) {
        // Если не удалось распарсить, оставляем поля пустыми
      }
    } else {
      // Используем значение по умолчанию
      _ipController.text = 'lepm.local';
      _portController.text = '8000';
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      final ip = _ipController.text.trim();
      final port = int.parse(_portController.text.trim());
      
      // Формируем URL
      final serverUrl = 'http://$ip:$port';
      
      // Сохраняем URL
      final prefs = await SharedPreferences.getInstance();
      final urlManager = BaseUrlManager();
      await urlManager.init(prefs);
      await urlManager.setServerUrl(serverUrl);
      
      // Обновляем API сервис
      ApiServiceProvider.updatePrefs(prefs);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Настройки сервера сохранены', style: TextStyle(color: PatrolColors.background)),
            backgroundColor: PatrolColors.statusSynced,
          ),
        );
        setState(() {
          _currentServerUrl = serverUrl;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка сохранения: $e', style: const TextStyle(color: PatrolColors.textPrimary)),
            backgroundColor: PatrolColors.statusPending,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _testResult = null;
    });

    try {
      final ip = _ipController.text.trim();
      final port = int.parse(_portController.text.trim());
      final testUrl = 'http://$ip:$port/health';
      
      final client = HttpClient();
      try {
        final uri = Uri.parse(testUrl);
        final request = await client.getUrl(uri).timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Таймаут подключения (5 секунд)');
          },
        );
        final httpResponse = await request.close().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            throw TimeoutException('Таймаут ответа (5 секунд)');
          },
        );
        
        final statusCode = httpResponse.statusCode;
        
        if (mounted) {
          setState(() {
            _testResult = statusCode == 200 
                ? '✓ Подключение успешно!' 
                : '⚠ Ошибка: код ответа $statusCode';
          });
        }
      } finally {
        client.close();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = '✗ Ошибка подключения: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateIp(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите IP адрес или доменное имя';
    }
    
    // Проверка на валидный IP или доменное имя
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    final domainRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
    
    if (!ipRegex.hasMatch(value) && !domainRegex.hasMatch(value) && value != 'localhost') {
      return 'Введите корректный IP адрес или доменное имя';
    }
    
    return null;
  }

  String? _validatePort(String? value) {
    if (value == null || value.isEmpty) {
      return 'Введите порт';
    }
    
    final port = int.tryParse(value);
    if (port == null || port < 1 || port > 65535) {
      return 'Порт должен быть числом от 1 до 65535';
    }
    
    return null;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PatrolColors.background,
      appBar: AppBar(
        backgroundColor: PatrolColors.background,
        elevation: 0,
        title: const Text('Настройки сервера', style: TextStyle(color: PatrolColors.textPrimary)),
        iconTheme: const IconThemeData(color: PatrolColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_currentServerUrl != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: PatrolColors.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Текущий сервер:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: PatrolColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentServerUrl!,
                        style: const TextStyle(fontSize: 16, color: PatrolColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ipController,
                style: const TextStyle(color: PatrolColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'IP адрес или доменное имя',
                  hintText: '192.168.1.100 или lepm.local',
                  prefixIcon: const Icon(Icons.dns, color: PatrolColors.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  labelStyle: const TextStyle(color: PatrolColors.textSecondary),
                  hintStyle: const TextStyle(color: PatrolColors.textSecondary),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: _validateIp,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                style: const TextStyle(color: PatrolColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Порт',
                  hintText: '8000',
                  prefixIcon: const Icon(Icons.settings_ethernet, color: PatrolColors.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  labelStyle: const TextStyle(color: PatrolColors.textSecondary),
                  hintStyle: const TextStyle(color: PatrolColors.textSecondary),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: _validatePort,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),
              if (_testResult != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _testResult!.contains('успешно')
                        ? PatrolColors.statusSynced.withOpacity(0.2)
                        : PatrolColors.statusPending.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _testResult!,
                    style: TextStyle(
                      color: _testResult!.contains('успешно')
                          ? PatrolColors.statusSynced
                          : PatrolColors.statusPending,
                    ),
                  ),
                ),
              if (_testResult != null) const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: const Icon(Icons.network_check, color: PatrolColors.accent),
                label: const Text('Проверить подключение', style: TextStyle(color: PatrolColors.accent)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: PatrolColors.accent),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: PatrolColors.background),
                      )
                    : const Icon(Icons.save, color: PatrolColors.background),
                label: Text(
                  _isLoading ? 'Сохранение...' : 'Сохранить настройки',
                  style: const TextStyle(color: PatrolColors.background),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: PatrolColors.accent,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PatrolColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Подсказки:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: PatrolColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('• Введите IP адрес сервера (например: 192.168.1.100)', style: TextStyle(color: PatrolColors.textSecondary)),
                    const Text('• Или доменное имя (например: lepm.local)', style: TextStyle(color: PatrolColors.textSecondary)),
                    const Text('• Порт по умолчанию: 8000', style: TextStyle(color: PatrolColors.textSecondary)),
                    const Text('• Используйте кнопку "Проверить подключение" для теста', style: TextStyle(color: PatrolColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Класс для таймаута
class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);
  @override
  String toString() => message;
}

