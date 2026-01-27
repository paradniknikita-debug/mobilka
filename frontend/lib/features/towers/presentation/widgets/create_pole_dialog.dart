import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/api_service.dart';
import '../../../../core/models/power_line.dart';

class CreatePoleDialog extends ConsumerStatefulWidget {
  final int powerLineId;
  final double? initialLatitude;
  final double? initialLongitude;

  const CreatePoleDialog({
    super.key,
    required this.powerLineId,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  ConsumerState<CreatePoleDialog> createState() => _CreatePoleDialogState();
}

class _CreatePoleDialogState extends ConsumerState<CreatePoleDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isGettingLocation = false;

  // Поля формы
  String _poleNumber = '';
  String _poleType = 'промежуточная';
  double? _latitude;
  double? _longitude;
  double? _height;
  String? _foundationType;
  String? _material;
  int? _yearInstalled;
  String _condition = 'good';
  String? _notes;

  // Параметры кабеля
  String? _conductorType = 'AC-70';
  String? _conductorMaterial = 'алюминий';
  String? _conductorSection = '70';
  
  // Отпаечная опора
  bool _isTap = false;

  final List<String> _poleTypes = [
    'анкерная',
    'промежуточная',
    'угловая',
    'концевая',
    'переходная',
    'транспозиционная',
  ];

  final List<String> _conductorTypes = [
    'AC-70',
    'AC-95',
    'AC-120',
    'AC-150',
    'AC-185',
    'AC-240',
    'AC-300',
  ];

  final List<String> _conductorMaterials = [
    'алюминий',
    'медь',
  ];

  @override
  void initState() {
    super.initState();
    // Устанавливаем начальные координаты из параметров
    // Если координаты переданы, используем их, иначе пытаемся получить текущие
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitude = widget.initialLatitude;
      _longitude = widget.initialLongitude;
    } else {
      // Если координаты не переданы, пытаемся получить текущие при инициализации
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _getCurrentLocation();
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Служба геолокации отключена. Включите её в настройках.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Разрешение на геолокацию отклонено.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Разрешение на геолокацию отклонено навсегда. Включите его в настройках.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Местоположение получено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка получения местоположения: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGettingLocation = false;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Необходимо указать координаты. Получите местоположение или введите вручную.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = ref.read(apiServiceProvider);

      final poleData = PoleCreate(
        poleNumber: _poleNumber,
        latitude: _latitude!,
        longitude: _longitude!,
        poleType: _poleType,
        height: _height,
        foundationType: _foundationType?.isEmpty ?? true ? null : _foundationType,
        material: _material?.isEmpty ?? true ? null : _material,
        yearInstalled: _yearInstalled,
        condition: _condition,
        notes: _notes?.isEmpty ?? true ? null : _notes,
        isTap: _isTap,
        conductorType: _conductorType,
        conductorMaterial: _conductorMaterial,
        conductorSection: _conductorSection,
      );

      await apiService.createPole(widget.powerLineId, poleData);

      if (mounted) {
        Navigator.of(context).pop(true); // Возвращаем true, чтобы обновить список
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Опора успешно создана'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка создания опоры: $e'),
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создание опоры'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Номер опоры
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Номер опоры *',
                  hintText: 'Например: ОП-001',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Введите номер опоры';
                  }
                  return null;
                },
                onSaved: (value) => _poleNumber = value ?? '',
                onChanged: (value) => _poleNumber = value,
              ),
              const SizedBox(height: 16),

              // Координаты
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Широта *',
                        hintText: '53.9045',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.my_location),
                          onPressed: _isGettingLocation ? null : _getCurrentLocation,
                          tooltip: 'Получить текущее местоположение',
                        ),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      initialValue: _latitude?.toString(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите широту';
                        }
                        final lat = double.tryParse(value);
                        if (lat == null || lat < -90 || lat > 90) {
                          return 'Широта должна быть от -90 до 90';
                        }
                        return null;
                      },
                      onSaved: (value) => _latitude = double.tryParse(value ?? ''),
                      onChanged: (value) {
                        final lat = double.tryParse(value);
                        if (lat != null) {
                          setState(() => _latitude = lat);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Долгота *',
                        hintText: '27.5615',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      initialValue: _longitude?.toString(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите долготу';
                        }
                        final lon = double.tryParse(value);
                        if (lon == null || lon < -180 || lon > 180) {
                          return 'Долгота должна быть от -180 до 180';
                        }
                        return null;
                      },
                      onSaved: (value) => _longitude = double.tryParse(value ?? ''),
                      onChanged: (value) {
                        final lon = double.tryParse(value);
                        if (lon != null) {
                          setState(() => _longitude = lon);
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (_isGettingLocation)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 16),

              // Тип опоры
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Тип опоры *'),
                value: _poleType,
                items: _poleTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _poleType = value ?? 'промежуточная');
                },
              ),
              const SizedBox(height: 16),

              // Параметры кабеля (для автоматического создания пролёта)
              const Divider(),
              const Text(
                'Параметры кабеля (для автоматического создания пролёта)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Марка провода'),
                value: _conductorType,
                items: _conductorTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _conductorType = value);
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Материал провода'),
                value: _conductorMaterial,
                items: _conductorMaterials.map((material) {
                  return DropdownMenuItem(
                    value: material,
                    child: Text(material),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _conductorMaterial = value);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Сечение провода, мм²',
                  hintText: '70',
                ),
                keyboardType: TextInputType.number,
                initialValue: _conductorSection,
                onChanged: (value) => _conductorSection = value.isEmpty ? null : value,
              ),
              const SizedBox(height: 16),

              // Отпаечная опора
              CheckboxListTile(
                title: const Text('Отпаечная опора'),
                subtitle: const Text('Укажите, если это точка отпайки (завершит текущий сегмент линии)'),
                value: _isTap,
                onChanged: (value) {
                  setState(() => _isTap = value ?? false);
                },
              ),
              const SizedBox(height: 16),

              // Дополнительные поля
              const Divider(),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Высота, м'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (value) => _height = double.tryParse(value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Тип фундамента'),
                onChanged: (value) => _foundationType = value.isEmpty ? null : value,
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Материал опоры'),
                onChanged: (value) => _material = value.isEmpty ? null : value,
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Год установки'),
                keyboardType: TextInputType.number,
                onChanged: (value) => _yearInstalled = int.tryParse(value),
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Заметки'),
                maxLines: 3,
                onChanged: (value) => _notes = value.isEmpty ? null : value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }
}

