import 'package:db_compat/db_compat.dart';

class Property {
  final String id;
  final String title;
  final String type;
  final String category;
  final String price;
  final String location;
  final String city;
  final String description;
  final List<String> images;
  final List<String> amenities;
  final String area;
  final String beds;
  final String baths;
  final String bathrooms;
  final String ownerName;
  final String ownerPhone;
  final String sellerId;
  final String status;
  final bool isFeatured;
  final DateTime? featuredUntil;
  final String plan;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String brokerName;
  final String brokerPhone;
  final String mapLocation;
  final DateTime createdAt;
  final DateTime? planExpiry;
  final DateTime? listingExpiry;
  final DateTime? planStartTime;
  final bool isActive;
  final bool isNegotiable;
  final String priceUnit;
  final String propertyFor;
  final String ownershipType;
  final String condition;
  final String videoLink;
  final String droneVideoLink;
  final String virtualTourLink;
  final Map<String, dynamic> extraDetails;
  final String propertyStatus;
  final String possession;
  final bool showFeaturedBadge;
  final bool featuredSection;
  final bool priorityListing;
  final int searchBoost;
  final String propertyCardBorder;
  final bool showVerifiedBadge;
  final int trustScore;
  final bool verifiedSectionVisible;
  final bool topSearchPlacement;
  final bool priorityReview;
  final bool premiumBadge;
  final bool eliteBadge;
  final bool dedicatedBroker;
  final int visibilityScore;
  final List<String> propertyProof;

  Property({
    this.planExpiry,
    this.listingExpiry,
    this.planStartTime,
    this.propertyFor = 'Sale',
    this.ownershipType = 'Owner',
    this.condition = 'New',
    this.videoLink = '',
    this.droneVideoLink = '',
    this.virtualTourLink = '',
    this.extraDetails = const {},
    required this.id,
    required this.title,
    required this.type,
    required this.category,
    required this.price,
    required this.location,
    this.city = '',
    required this.description,
    required this.images,
    required this.amenities,
    required this.area,
    this.beds = '0',
    this.baths = '0',
    this.bathrooms = '0',
    this.ownerName = '',
    this.ownerPhone = '',
    this.sellerId = '',
    this.status = 'available',
    this.isFeatured = false,
    this.featuredUntil,
    this.plan = '',
    this.isVerified = false,
    this.verifiedAt,
    this.brokerName = 'MULTIVERSE Property Desk',
    this.brokerPhone = '',
    this.mapLocation = '',
    this.isActive = true,
    this.isNegotiable = false,
    this.priceUnit = 'Total Price',
    this.propertyStatus = '',
    this.possession = '',
    this.showFeaturedBadge = false,
    this.featuredSection = false,
    this.priorityListing = false,
    this.searchBoost = 0,
    this.propertyCardBorder = 'none',
    this.showVerifiedBadge = false,
    this.trustScore = 0,
    this.verifiedSectionVisible = false,
    this.topSearchPlacement = false,
    this.priorityReview = false,
    this.premiumBadge = false,
    this.eliteBadge = false,
    this.dedicatedBroker = false,
    this.visibilityScore = 0,
    this.propertyProof = const [],
    required this.createdAt,
  });

  factory Property.fromMap(Map<String, dynamic> map, String id) {
    final bedrooms = _stringValue(map['bedrooms'] ?? map['beds'] ?? '0');
    final bathrooms = _stringValue(map['bathrooms'] ?? map['baths'] ?? '0');
    final rawPrice = map['price'];
    final formattedPrice = rawPrice is num ? _formatCurrency(rawPrice) : _stringValue(rawPrice);
    final rawArea = map['area'] ?? map['sqft'] ?? '';
    final formattedArea = rawArea is num ? '${rawArea.toStringAsFixed(0)} sqft' : _stringValue(rawArea);

    return Property(
      planExpiry: _dateValue(map['planExpiry']) ?? (
          (map['plan'] != 'free' && map['plan'] != null) 
            ? _dateValue(map['createdAt'])?.add(const Duration(days: 30)) 
            : null
      ),
      listingExpiry: _dateValue(map['listingExpiry']) ?? (_dateValue(map['createdAt'])?.add(const Duration(days: 30))),
      planStartTime: _dateValue(map['planStartTime']) ?? _dateValue(map['createdAt']),
      propertyFor: _stringValue(map['propertyFor']),
      ownershipType: _stringValue(map['ownershipType']),
      condition: _stringValue(map['condition']),
      videoLink: _stringValue(map['videoLink']),
      droneVideoLink: _stringValue(map['droneVideoLink']),
      virtualTourLink: _stringValue(map['virtualTourLink']),
      extraDetails: Map<String, dynamic>.from(map),
      id: id,
      title: _stringValue(map['title'] ?? map['name']),
      type: _stringValue(map['type'] ?? map['category']),
      category: _stringValue(map['category'] ?? map['type']),
      price: formattedPrice,
      location: _stringValue(map['location'] ?? map['address']),
      city: _stringValue(map['city']),
      description: _stringValue(map['description']),
      images: List<String>.from(map['images'] ?? []),
      amenities: List<String>.from(map['amenities'] ?? []),
      area: formattedArea,
      beds: bedrooms,
      baths: bathrooms,
      bathrooms: bathrooms,
      ownerName: _stringValue(map['ownerName'] ?? map['owner']),
      ownerPhone: _stringValue(map['ownerPhone'] ?? map['phone']),
      sellerId: _stringValue(map['sellerId'] ?? map['userId']),
      status: _stringValue(map['status']).isEmpty ? 'available' : _stringValue(map['status']),
      isFeatured: map['isFeatured'] ?? false,
      featuredUntil: _dateValue(map['featuredUntil']),
      plan: _stringValue(map['plan'] ?? map['featuredPlan']),
      isVerified: map['isVerified'] ?? false,
      verifiedAt: _dateValue(map['verifiedAt']),
      brokerName: _stringValue(map['brokerName']).isEmpty
          ? 'MULTIVERSE Property Desk'
          : _stringValue(map['brokerName']),
      brokerPhone: _stringValue(map['brokerPhone']),
      mapLocation: _stringValue(map['mapLocation']),
      isActive: map['isActive'] ?? true,
      isNegotiable: map['isNegotiable'] ?? false,
      priceUnit: _stringValue(map['priceUnit']),
      propertyStatus: _stringValue(map['propertyStatus']),
      possession: _stringValue(map['possession']),
      showFeaturedBadge: map['showFeaturedBadge'] ?? false,
      featuredSection: map['featuredSection'] ?? false,
      priorityListing: map['priorityListing'] ?? false,
      searchBoost: map['searchBoost'] ?? 0,
      propertyCardBorder: map['propertyCardBorder'] ?? 'none',
      showVerifiedBadge: map['showVerifiedBadge'] ?? false,
      trustScore: map['trustScore'] ?? 0,
      verifiedSectionVisible: map['verifiedSectionVisible'] ?? false,
      topSearchPlacement: map['topSearchPlacement'] ?? false,
      priorityReview: map['priorityReview'] ?? false,
      premiumBadge: map['premiumBadge'] ?? false,
      eliteBadge: map['eliteBadge'] ?? false,
      dedicatedBroker: map['dedicatedBroker'] ?? false,
      visibilityScore: map['visibilityScore'] ?? 0,
      propertyProof: List<String>.from(map['propertyProof'] ?? []),
      createdAt: _dateValue(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    final priceNumber = double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    final areaNumber = double.tryParse(area.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

    return {
      'planExpiry': planExpiry == null ? null : Timestamp.fromDate(planExpiry!),
      'listingExpiry': listingExpiry == null ? null : Timestamp.fromDate(listingExpiry!),
      'planStartTime': planStartTime == null ? null : Timestamp.fromDate(planStartTime!),
      'propertyFor': propertyFor,
      'ownershipType': ownershipType,
      'condition': condition,
      'videoLink': videoLink,
      'droneVideoLink': droneVideoLink,
      'virtualTourLink': virtualTourLink,
      'title': title,
      'type': type,
      'category': category,
      'price': priceNumber,
      'isNegotiable': isNegotiable,
      'location': location,
      'city': city,
      'description': description,
      'images': images,
      'amenities': amenities,
      'area': areaNumber,
      'bedrooms': int.tryParse(beds) ?? 0,
      'bathrooms': int.tryParse(bathrooms) ?? int.tryParse(baths) ?? 0,
      'ownerName': ownerName,
      'ownerPhone': ownerPhone,
      'sellerId': sellerId,
      'status': status,
      'isFeatured': isFeatured,
      'featuredUntil': featuredUntil == null ? null : Timestamp.fromDate(featuredUntil!),
      'plan': plan,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt == null ? null : Timestamp.fromDate(verifiedAt!),
      'brokerName': brokerName,
      'brokerPhone': brokerPhone,
      'mapLocation': mapLocation,
      'isActive': isActive,
      'priceUnit': priceUnit,
      'propertyStatus': propertyStatus,
      'possession': possession,
      'showFeaturedBadge': showFeaturedBadge,
      'featuredSection': featuredSection,
      'priorityListing': priorityListing,
      'searchBoost': searchBoost,
      'propertyCardBorder': propertyCardBorder,
      'showVerifiedBadge': showVerifiedBadge,
      'trustScore': trustScore,
      'verifiedSectionVisible': verifiedSectionVisible,
      'topSearchPlacement': topSearchPlacement,
      'priorityReview': priorityReview,
      'premiumBadge': premiumBadge,
      'eliteBadge': eliteBadge,
      'dedicatedBroker': dedicatedBroker,
      'visibilityScore': visibilityScore,
      'propertyProof': propertyProof,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  bool get isApproved => status == 'approved' || status == 'available';

  static String _stringValue(dynamic value) => value?.toString() ?? '';

  static DateTime? _dateValue(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _formatCurrency(num value) {
    if (value >= 10000000) {
      double val = value / 10000000;
      String s = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1);
      return '₹${s}CR';
    }
    if (value >= 100000) {
      double val = value / 100000;
      String s = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1);
      return '₹${s}L';
    }
    if (value >= 1000) {
      double val = value / 1000;
      String s = val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 1);
      return '₹${s}k';
    }
    return '₹${value.toStringAsFixed(0)}';
  }
}
