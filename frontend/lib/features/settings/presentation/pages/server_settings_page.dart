import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/base_url_manager.dart';
import '../../../../core/services/api_service.dart';

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
            content: Text('Настройки сервера сохранены'),
            backgroundColor: Colors.green,
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
            content: Text('Ошибка сохранения: $e'),
            backgroundColor: Colors.red,
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
      appBar: AppBar(
        title: const Text('Настройки сервера'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Информация о текущем сервере
              if (_currentServerUrl != null)
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Текущий сервер:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentServerUrl!,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Поле ввода IP адреса
              TextFormField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP адрес или доменное имя',
                  hintText: '192.168.1.100 или lepm.local',
                  prefixIcon: Icon(Icons.dns),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: _validateIp,
                enabled: !_isLoading,
              ),
              
              const SizedBox(height: 16),
              
              // Поле ввода порта
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Порт',
                  hintText: '8000',
                  prefixIcon: Icon(Icons.settings_ethernet),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                validator: _validatePort,
                enabled: !_isLoading,
              ),
              
              const SizedBox(height: 24),
              
              // Результат теста
              if (_testResult != null)
                Card(
                  color: _testResult!.contains('успешно') 
                      ? Colors.green.shade50 
                      : Colors.red.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _testResult!,
                      style: TextStyle(
                        color: _testResult!.contains('успешно') 
                            ? Colors.green.shade900 
                            : Colors.red.shade900,
                      ),
                    ),
                  ),
                ),
              
              if (_testResult != null) const SizedBox(height: 16),
              
              // Кнопка тестирования
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: const Icon(Icons.network_check),
                label: const Text('Проверить подключение'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Кнопка сохранения
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveSettings,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoading ? 'Сохранение...' : 'Сохранить настройки'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Подсказки
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Подсказки:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('• Введите IP адрес сервера (например: 192.168.1.100)'),
                      const Text('• Или доменное имя (например: lepm.local)'),
                      const Text('• Порт по умолчанию: 8000'),
                      const Text('• Используйте кнопку "Проверить подключение" для теста'),
                    ],
                  ),
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

