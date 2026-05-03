class CartItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String image;
  final String shopId;
  final String shopName;
  final String? vendorId;
  final double? shopLat;
  final double? shopLng;
  final String deliveryType;

  CartItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    required this.image,
    required this.shopId,
    required this.shopName,
    this.vendorId,
    this.shopLat,
    this.shopLng,
    this.deliveryType = 'normal',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'image': image,
      'shopId': shopId,
      'shopName': shopName,
      'vendorId': vendorId,
      'shopLat': shopLat,
      'shopLng': shopLng,
      'deliveryType': deliveryType,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      name: map['name'],
      quantity: map['quantity'],
      price: map['price'],
      image: map['image'],
      shopId: map['shopId'],
      shopName: map['shopName'],
      vendorId: map['vendorId'] as String?,
      shopLat: (map['shopLat'] as num?)?.toDouble(),
      shopLng: (map['shopLng'] as num?)?.toDouble(),
      deliveryType: map['deliveryType'] as String? ?? 'normal',
    );
  }
}
