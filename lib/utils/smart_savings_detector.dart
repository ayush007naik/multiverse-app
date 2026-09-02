/// Smart Savings Detection Engine
/// Automatically calculates savings based on cart item categories
class SmartSavingsDetector {
  
  /// Detect categories from cart items and calculate total savings
  static SavingsResult calculateSavings(List<Map<String, dynamic>> cartItems) {
    final Map<String, List<Map<String, dynamic>>> categorizedItems = {};
    
    // Group items by category
    for (final item in cartItems) {
      final category = _detectCategory(item);
      if (!categorizedItems.containsKey(category)) {
        categorizedItems[category] = [];
      }
      categorizedItems[category]!.add(item);
    }
    
    // Calculate savings for each category
    double totalMoneySaved = 0;
    int totalMinutesSaved = 0;
    final List<String> breakdownMessages = [];
    
    categorizedItems.forEach((category, items) {
      final savings = _calculateCategorySavings(category, items);
      totalMoneySaved += savings.moneySaved;
      totalMinutesSaved += savings.minutesSaved;
      if (savings.message.isNotEmpty) {
        breakdownMessages.add(savings.message);
      }
    });
    
    return SavingsResult(
      moneySaved: totalMoneySaved,
      minutesSaved: totalMinutesSaved,
      breakdownMessages: breakdownMessages,
    );
  }
  
  /// Detect category from item metadata
  static String _detectCategory(Map<String, dynamic> item) {
    final name = (item['name'] ?? '').toString().toLowerCase();
    final category = (item['category'] ?? '').toString().toLowerCase();
    final combined = '$category $name';
    
    // Grocery detection
    if (combined.contains('grocery') || 
        combined.contains('vegetable') || 
        combined.contains('fruit') ||
        combined.contains('milk') ||
        combined.contains('bread') ||
        combined.contains('rice') ||
        combined.contains('atta') ||
        combined.contains('dal') ||
        combined.contains('sugar') ||
        combined.contains('oil')) {
      return 'grocery';
    }
    
    // Pharmacy detection
    if (combined.contains('pharmacy') || 
        combined.contains('medicine') ||
        combined.contains('tablet') ||
        combined.contains('capsule') ||
        combined.contains('syrup') ||
        combined.contains('health')) {
      return 'pharmacy';
    }
    
    // Materials/Hardware detection
    if (combined.contains('cement') || 
        combined.contains('brick') ||
        combined.contains('sand') ||
        combined.contains('hardware') ||
        combined.contains('tool') ||
        combined.contains('paint') ||
        combined.contains('material')) {
      return 'materials';
    }
    
    // Furniture detection
    if (combined.contains('furniture') || 
        combined.contains('sofa') ||
        combined.contains('table') ||
        combined.contains('chair') ||
        combined.contains('bed') ||
        combined.contains('almirah')) {
      return 'furniture';
    }
    
    // Electronics detection
    if (combined.contains('electronic') || 
        combined.contains('phone') ||
        combined.contains('laptop') ||
        combined.contains('charger') ||
        combined.contains('headphone')) {
      return 'electronics';
    }
    
    // Books detection
    if (combined.contains('book') || 
        combined.contains('notebook') ||
        combined.contains('pen') ||
        combined.contains('stationery')) {
      return 'books';
    }
    
    // Default to general
    return 'general';
  }
  
  /// Calculate savings for specific category
  static CategorySavings _calculateCategorySavings(
    String category, 
    List<Map<String, dynamic>> items,
  ) {
    switch (category) {
      case 'grocery':
        return _calculateGrocerySavings(items);
      case 'pharmacy':
        return _calculatePharmacySavings(items);
      case 'materials':
        return _calculateMaterialsSavings(items);
      case 'furniture':
        return _calculateFurnitureSavings(items);
      case 'electronics':
        return _calculateElectronicsSavings(items);
      case 'books':
        return _calculateBooksSavings(items);
      default:
        return _calculateGeneralSavings(items);
    }
  }
  
  /// GROCERY SAVINGS
  /// - Petrol cost for market travel
  /// - Parking fees
  /// - Travel time in traffic
  static CategorySavings _calculateGrocerySavings(List<Map<String, dynamic>> items) {
    final itemCount = items.fold<int>(
      0, 
      (sum, item) => sum + (item['quantity'] as int? ?? 1),
    );
    
    // Average grocery trip: 5km each way = 10km total
    // Petrol cost: ₹8/km (average bike)
    const petrolCost = 80; // 10km × ₹8
    
    // Parking at market
    const parkingCost = 20;
    
    // Time: 30 min each way + 30 min shopping = 90 min total
    const travelTime = 90;
    
    // More items = more shopping time
    final shoppingTime = itemCount * 5; // 5 min per item
    
    const totalMoney = petrolCost + parkingCost;
    final totalTime = travelTime + shoppingTime;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You saved approx ₹$totalMoney and ${_formatTime(totalTime)} by ordering online.',
    );
  }
  
  /// PHARMACY SAVINGS
  /// - Emergency convenience
  /// - Night travel avoided
  /// - Queue time at pharmacy
  static CategorySavings _calculatePharmacySavings(List<Map<String, dynamic>> items) {
    // Pharmacy trip: 3km each way
    const petrolCost = 48; // 6km × ₹8
    
    // Queue time at pharmacy (avg 20 min)
    const queueTime = 20;
    
    // Travel time: 15 min each way
    const travelTime = 30;
    
    const totalMoney = petrolCost;
    const totalTime = queueTime + travelTime;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You avoided pharmacy queue and saved approx ₹$totalMoney + ${_formatTime(totalTime)}.',
    );
  }
  
  /// MATERIALS/HARDWARE SAVINGS
  /// - Heavy vehicle rent avoided
  /// - Loading/unloading labor
  /// - Fuel for transport vehicle
  static CategorySavings _calculateMaterialsSavings(List<Map<String, dynamic>> items) {
    final totalWeight = items.fold<double>(
      0.0,
      (sum, item) {
        final qty = item['quantity'] as int? ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0;
        // Rough estimate: ₹100 = 10kg average
        return sum + (price / 100) * 10 * qty;
      },
    );
    
    // Auto/Tempo cost for heavy materials
    double vehicleRent = 0;
    if (totalWeight > 100) {
      vehicleRent = 500; // Tempo
    } else if (totalWeight > 50) {
      vehicleRent = 300; // Auto
    } else {
      vehicleRent = 150; // Bike taxi
    }
    
    // Loading/unloading labor: ₹200
    const laborCost = 200;
    
    // Time: 2 hours for transport + loading
    const totalTime = 120;
    
    final totalMoney = vehicleRent + laborCost;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You avoided heavy transport costs and saved approx ₹$totalMoney.',
    );
  }
  
  /// FURNITURE SAVINGS
  /// - Transport vehicle (tempi/tractor)
  /// - Loading labor (2-3 people needed)
  static CategorySavings _calculateFurnitureSavings(List<Map<String, dynamic>> items) {
    final itemCount = items.length;
    
    // Furniture transport: Tempo/Truck
    double transportCost = 0;
    if (itemCount > 3) {
      transportCost = 800; // Truck
    } else if (itemCount > 1) {
      transportCost = 500; // Tempo
    } else {
      transportCost = 300; // Auto
    }
    
    // Loading/unloading: 2 people × ₹300
    const laborCost = 600;
    
    // Time: 3 hours for transport + setup
    const totalTime = 180;
    
    final totalMoney = transportCost + laborCost;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You saved ₹$totalMoney on transport & labor for furniture delivery.',
    );
  }
  
  /// ELECTRONICS SAVINGS
  /// - City travel to electronics market
  /// - Fuel + time in traffic
  static CategorySavings _calculateElectronicsSavings(List<Map<String, dynamic>> items) {
    // Electronics market trip: 8km each way (usually in city center)
    const petrolCost = 128; // 16km × ₹8
    
    // Parking in commercial area
    const parkingCost = 40;
    
    // Time: 40 min each way + 60 min shopping/comparison
    const totalTime = 140;
    
    const totalMoney = petrolCost + parkingCost;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You saved approx ₹$totalMoney and ${_formatTime(totalTime)} by avoiding city travel.',
    );
  }
  
  /// BOOKS SAVINGS
  /// - Travel to bookstore/market
  /// - Browsing time
  static CategorySavings _calculateBooksSavings(List<Map<String, dynamic>> items) {
    // Bookstore trip: 5km each way
    const petrolCost = 80; // 10km × ₹8
    
    // Parking
    const parkingCost = 20;
    
    // Time: 25 min each way + 45 min browsing
    const totalTime = 95;
    
    const totalMoney = petrolCost + parkingCost;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You saved approx ₹$totalMoney and ${_formatTime(totalTime)} by ordering online.',
    );
  }
  
  /// GENERAL SAVINGS (fallback)
  static CategorySavings _calculateGeneralSavings(List<Map<String, dynamic>> items) {
    // Average shop trip
    const petrolCost = 60;
    const parkingCost = 20;
    const totalTime = 60;
    
    const totalMoney = petrolCost + parkingCost;
    
    return CategorySavings(
      moneySaved: totalMoney.toDouble(),
      minutesSaved: totalTime,
      message: 'You saved approx ₹$totalMoney and ${_formatTime(totalTime)} on travel.',
    );
  }
  
  /// Format minutes to readable time
  static String _formatTime(int minutes) {
    if (minutes < 60) {
      return '$minutes mins';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }
}

/// Result of savings calculation
class SavingsResult {
  final double moneySaved;
  final int minutesSaved;
  final List<String> breakdownMessages;
  
  SavingsResult({
    required this.moneySaved,
    required this.minutesSaved,
    required this.breakdownMessages,
  });
  
  String get formattedMoney => '₹${moneySaved.toStringAsFixed(0)}';
  String get formattedTime {
    if (minutesSaved < 60) {
      return '$minutesSaved mins';
    }
    final hours = minutesSaved ~/ 60;
    final mins = minutesSaved % 60;
    if (mins == 0) {
      return '${hours}h';
    }
    return '${hours}h ${mins}m';
  }
  
  String get summaryMessage {
    return 'Estimated total savings: $formattedMoney + $formattedTime saved.';
  }
}

/// Individual category savings
class CategorySavings {
  final double moneySaved;
  final int minutesSaved;
  final String message;
  
  CategorySavings({
    required this.moneySaved,
    required this.minutesSaved,
    required this.message,
  });
}
