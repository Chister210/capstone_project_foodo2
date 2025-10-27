class DonationSpecification {
  final String id;
  final String name;
  final String description;

  const DonationSpecification({
    required this.id,
    required this.name,
    required this.description,
  });

  static const List<DonationSpecification> specifications = [
    DonationSpecification(
      id: 'piece',
      name: 'By Piece',
      description: 'Individual items (e.g., 1 apple, 1 chicken)',
    ),
    DonationSpecification(
      id: 'bulk',
      name: 'Bulk',
      description: 'Large quantities (e.g., 1 sack of rice)',
    ),
    DonationSpecification(
      id: 'pack',
      name: 'By Pack',
      description: 'Pre-packaged items (e.g., 1 pack of 6 eggs)',
    ),
    DonationSpecification(
      id: 'kilogram',
      name: 'By Kilogram',
      description: 'Weight-based (e.g., 2kg of meat)',
    ),
    DonationSpecification(
      id: 'liter',
      name: 'By Liter',
      description: 'Volume-based (e.g., 1L of milk)',
    ),
    DonationSpecification(
      id: 'serving',
      name: 'By Serving',
      description: 'Portion-based (e.g., 10 servings of cooked food)',
    ),
  ];

  static DonationSpecification? getById(String id) {
    try {
      return specifications.firstWhere((spec) => spec.id == id);
    } catch (e) {
      return null;
    }
  }
}
