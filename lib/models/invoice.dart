// 📁 lib/models/invoice.dart
// Invoice Model for Multiverse

import 'package:db_compat/db_compat.dart';

class Invoice {
  final String id;
  final String invoiceNumber;
  final String orderId;
  final String customerEmail;
  final String customerName;
  final String customerPhone;
  final String deliveryAddress;
  final String shopName;
  final String shopGstin;
  final String shopAddress;
  final String shopContact;
  final List<InvoiceItem> items;
  final double subtotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double deliveryGst;
  final double platformProfitGst;
  final double deliveryCharges;
  final double platformFee;
  final double discount;
  final double grandTotal;
  final String paymentId;
  final String paymentStatus;
  final String paymentMethod;
  final DateTime createdAt;
  final String? pdfUrl;
  final bool emailSent;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.orderId,
    required this.customerEmail,
    required this.customerName,
    required this.customerPhone,
    required this.deliveryAddress,
    required this.shopName,
    required this.shopGstin,
    required this.shopAddress,
    required this.shopContact,
    required this.items,
    required this.subtotal,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    this.deliveryGst = 0,
    this.platformProfitGst = 0,
    this.deliveryCharges = 0,
    this.platformFee = 0,
    this.discount = 0,
    required this.grandTotal,
    required this.paymentId,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.createdAt,
    this.pdfUrl,
    this.emailSent = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoiceNumber': invoiceNumber,
      'orderId': orderId,
      'customerEmail': customerEmail,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'deliveryAddress': deliveryAddress,
      'shopName': shopName,
      'shopGstin': shopGstin,
      'shopAddress': shopAddress,
      'shopContact': shopContact,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'deliveryGst': deliveryGst,
      'platformProfitGst': platformProfitGst,
      'deliveryCharges': deliveryCharges,
      'platformFee': platformFee,
      'discount': discount,
      'grandTotal': grandTotal,
      'paymentId': paymentId,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'createdAt': createdAt.toIso8601String(),
      'pdfUrl': pdfUrl,
      'emailSent': emailSent,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    return Invoice(
      id: map['id'] ?? '',
      invoiceNumber: map['invoiceNumber'] ?? '',
      orderId: map['orderId'] ?? '',
      customerEmail: map['customerEmail'] ?? '',
      customerName: map['customerName'] ?? '',
      customerPhone: map['customerPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      shopName: map['shopName'] ?? '',
      shopGstin: map['shopGstin'] ?? '',
      shopAddress: map['shopAddress'] ?? '',
      shopContact: map['shopContact'] ?? '',
      items: (map['items'] is List
              ? (map['items'] as List)
                  .map((item) => InvoiceItem.fromMap(item))
                  .toList()
              : const []),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      cgst: (map['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (map['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (map['igst'] as num?)?.toDouble() ?? 0.0,
      deliveryGst: (map['deliveryGst'] as num?)?.toDouble() ?? 0.0,
      platformProfitGst: (map['platformProfitGst'] as num?)?.toDouble() ?? 0.0,
      deliveryCharges: (map['deliveryCharges'] as num?)?.toDouble() ?? 0.0,
      platformFee: (map['platformFee'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (map['grandTotal'] as num?)?.toDouble() ?? 0.0,
      paymentId: map['paymentId'] ?? '',
      paymentStatus: map['paymentStatus'] ?? '',
      paymentMethod: map['paymentMethod'] ?? '',
      createdAt: parseDate(map['createdAt']),
      pdfUrl: map['pdfUrl'],
      emailSent: map['emailSent'] ?? false,
    );
  }
}

class InvoiceItem {
  final String name;
  final int quantity;
  final double price;
  final double gstPercent;
  final double total;
  final String? category;

  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.gstPercent = 0,
    required this.total,
    this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'price': price,
      'gstPercent': gstPercent,
      'total': total,
      'category': category,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map) {
    return InvoiceItem(
      name: map['name'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (map['gstPercent'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String?,
    );
  }
}
