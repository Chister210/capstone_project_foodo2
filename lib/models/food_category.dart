class FoodCategory {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String color;

  const FoodCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
  });

  static const List<FoodCategory> categories = [
    FoodCategory(
      id: 'fruits',
      name: 'Fruits',
      description: 'Fresh fruits and vegetables',
      icon: '🍎',
      color: '#FF6B6B',
    ),
    FoodCategory(
      id: 'vegetables',
      name: 'Vegetables',
      description: 'Fresh vegetables and greens',
      icon: '🥬',
      color: '#4ECDC4',
    ),
    FoodCategory(
      id: 'meat',
      name: 'Meat',
      description: 'Beef, pork, and other meats',
      icon: '🥩',
      color: '#FF8E53',
    ),
    FoodCategory(
      id: 'poultry',
      name: 'Poultry',
      description: 'Chicken, duck, and other poultry',
      icon: '🍗',
      color: '#FFD93D',
    ),
    FoodCategory(
      id: 'seafood',
      name: 'Seafood',
      description: 'Fish, shrimp, and other seafood',
      icon: '🐟',
      color: '#6BCF7F',
    ),
    FoodCategory(
      id: 'dairy',
      name: 'Dairy',
      description: 'Milk, cheese, and dairy products',
      icon: '🥛',
      color: '#4D96FF',
    ),
    FoodCategory(
      id: 'grains',
      name: 'Grains',
      description: 'Rice, bread, and grain products',
      icon: '🍞',
      color: '#DDA0DD',
    ),
    FoodCategory(
      id: 'beverages',
      name: 'Beverages',
      description: 'Drinks and liquid products',
      icon: '🥤',
      color: '#98D8C8',
    ),
    FoodCategory(
      id: 'snacks',
      name: 'Snacks',
      description: 'Chips, cookies, and snack foods',
      icon: '🍪',
      color: '#F7DC6F',
    ),
    FoodCategory(
      id: 'cooked_food',
      name: 'Cooked Food',
      description: 'Prepared meals and cooked dishes',
      icon: '🍲',
      color: '#BB8FCE',
    ),
    FoodCategory(
      id: 'other',
      name: 'Other',
      description: 'Other food items not listed',
      icon: '🍽️',
      color: '#85C1E9',
    ),
  ];

  static FoodCategory? getById(String id) {
    try {
      return categories.firstWhere((category) => category.id == id);
    } catch (e) {
      return null;
    }
  }
}
