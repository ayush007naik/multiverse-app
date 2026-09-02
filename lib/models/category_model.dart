class Category {
  final String name;
  final String imagePath;
  final String? id; // Optional ID for navigation

  const Category({
    required this.name,
    required this.imagePath,
    this.id,
  });

  Category copyWith({
    String? name,
    String? imagePath,
    String? id,
  }) {
    return Category(
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      id: id ?? this.id,
    );
  }
}

const List<Category> allCategories = [
  Category(name: 'Grocery', imagePath: 'assets/categories/grocery.png'),
  Category(name: 'Restaurant', imagePath: 'assets/categories/restaurant.png'),
  Category(name: 'Pharmacy', imagePath: 'assets/categories/pharmacy.png'),
  Category(name: 'Electronics', imagePath: 'assets/categories/electronics.png'),
  Category(name: 'Fashion', imagePath: 'assets/categories/fashion.png'),
  Category(name: 'Beauty', imagePath: 'assets/categories/beauty.png'),
  Category(name: 'Home', imagePath: 'assets/categories/home.png'),
  Category(name: 'Baby & Kids', imagePath: 'assets/categories/babykids.png'),
  Category(name: 'Furniture', imagePath: 'assets/categories/furniture.png'),
  Category(name: 'Books', imagePath: 'assets/categories/books.png'),
  Category(name: 'Hardware', imagePath: 'assets/categories/hardware.png'),
  Category(name: 'Materials', imagePath: 'assets/categories/materials.png'),
  Category(name: 'Home Care', imagePath: 'assets/categories/home_care.png'),
  Category(name: 'Automotive', imagePath: 'assets/categories/automative.png'),
  Category(name: 'Agriculture', imagePath: 'assets/categories/agriculture.png'),
  Category(name: 'Accessories', imagePath: 'assets/categories/acessories.png'),
  Category(name: 'Gifts', imagePath: 'assets/categories/gifts.png'),
  Category(name: 'Sports', imagePath: 'assets/categories/sports.png'),
  Category(name: 'Meat', imagePath: 'assets/categories/meat.png'),
  Category(name: 'Others', imagePath: 'assets/categories/others.png'),
];