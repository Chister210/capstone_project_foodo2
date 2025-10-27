class BeneficiaryType {
  final String id;
  final String name;
  final String description;
  final String icon;

  const BeneficiaryType({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
  });

  static const List<BeneficiaryType> types = [
    BeneficiaryType(
      id: 'orphanage',
      name: 'Orphanage Staff',
      description: 'Staff member of an orphanage or children\'s home',
      icon: '🏠',
    ),
    BeneficiaryType(
      id: 'animal_shelter',
      name: 'Animal Shelter Staff',
      description: 'Staff member of an animal shelter or rescue center',
      icon: '🐕',
    ),
    BeneficiaryType(
      id: 'elderly_care',
      name: 'Elderly Care Staff',
      description: 'Staff member of a senior care facility',
      icon: '👴',
    ),
    BeneficiaryType(
      id: 'homeless_shelter',
      name: 'Homeless Shelter Staff',
      description: 'Staff member of a homeless shelter or soup kitchen',
      icon: '🏘️',
    ),
    BeneficiaryType(
      id: 'community_center',
      name: 'Community Center Staff',
      description: 'Staff member of a community center or church',
      icon: '⛪',
    ),
    BeneficiaryType(
      id: 'school',
      name: 'School Staff',
      description: 'Teacher or staff member of a school',
      icon: '🏫',
    ),
    BeneficiaryType(
      id: 'individual',
      name: 'Individual',
      description: 'Individual in need of food assistance',
      icon: '👤',
    ),
  ];

  static BeneficiaryType? getById(String id) {
    try {
      return types.firstWhere((type) => type.id == id);
    } catch (e) {
      return null;
    }
  }
}
