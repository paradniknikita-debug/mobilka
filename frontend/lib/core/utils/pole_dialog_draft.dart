/// Черновик карточки опоры при возврате с карты после «Указать на карте».
class PoleDialogDraft {
  const PoleDialogDraft({
    this.latitude,
    this.longitude,
    this.poleNumber,
    this.poleType,
    this.height,
    this.foundationType,
    this.material,
    this.yearInstalled,
    this.condition,
    this.notes,
    this.structuralDefect,
    this.structuralCrit,
    this.conductorType,
    this.conductorMaterial,
    this.conductorSection,
    this.isTap,
    this.branchSelection,
    this.autofill = false,
  });

  final double? latitude;
  final double? longitude;
  final String? poleNumber;
  final String? poleType;
  final double? height;
  final String? foundationType;
  final String? material;
  final int? yearInstalled;
  final String? condition;
  final String? notes;
  final String? structuralDefect;
  final String? structuralCrit;
  final String? conductorType;
  final String? conductorMaterial;
  final String? conductorSection;
  final bool? isTap;
  final String? branchSelection;
  final bool autofill;

  Map<String, dynamic> toJson() => {
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (poleNumber != null) 'pole_number': poleNumber,
        if (poleType != null) 'pole_type': poleType,
        if (height != null) 'height': height,
        if (foundationType != null) 'foundation_type': foundationType,
        if (material != null) 'material': material,
        if (yearInstalled != null) 'year_installed': yearInstalled,
        if (condition != null) 'condition': condition,
        if (notes != null) 'notes': notes,
        if (structuralDefect != null) 'structural_defect': structuralDefect,
        if (structuralCrit != null) 'structural_crit': structuralCrit,
        if (conductorType != null) 'conductor_type': conductorType,
        if (conductorMaterial != null) 'conductor_material': conductorMaterial,
        if (conductorSection != null) 'conductor_section': conductorSection,
        if (isTap != null) 'is_tap': isTap,
        if (branchSelection != null) 'branch_selection': branchSelection,
        'autofill': autofill,
      };

  factory PoleDialogDraft.fromJson(Map<String, dynamic> json) => PoleDialogDraft(
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        poleNumber: json['pole_number'] as String?,
        poleType: json['pole_type'] as String?,
        height: (json['height'] as num?)?.toDouble(),
        foundationType: json['foundation_type'] as String?,
        material: json['material'] as String?,
        yearInstalled: json['year_installed'] as int?,
        condition: json['condition'] as String?,
        notes: json['notes'] as String?,
        structuralDefect: json['structural_defect'] as String?,
        structuralCrit: json['structural_crit'] as String?,
        conductorType: json['conductor_type'] as String?,
        conductorMaterial: json['conductor_material'] as String?,
        conductorSection: json['conductor_section'] as String?,
        isTap: json['is_tap'] as bool?,
        branchSelection: json['branch_selection'] as String?,
        autofill: json['autofill'] == true,
      );

  PoleDialogDraft copyWith({
    double? latitude,
    double? longitude,
  }) =>
      PoleDialogDraft(
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        poleNumber: poleNumber,
        poleType: poleType,
        height: height,
        foundationType: foundationType,
        material: material,
        yearInstalled: yearInstalled,
        condition: condition,
        notes: notes,
        structuralDefect: structuralDefect,
        structuralCrit: structuralCrit,
        conductorType: conductorType,
        conductorMaterial: conductorMaterial,
        conductorSection: conductorSection,
        isTap: isTap,
        branchSelection: branchSelection,
        autofill: autofill,
      );
}
