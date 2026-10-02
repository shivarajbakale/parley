/// The figures the home screen opens on.
///
/// Hand-written rather than freezed, which is the choice
/// `library_item.dart` describes: four fields and no `copyWith` caller does
/// not earn a generated file. Reach for freezed the moment this grows.
///
/// It is served by the mock backend at `/api/dashboard`, and the mock
/// **derives it from the same store the Library reads** rather than returning
/// invented figures. That is deliberate: a demo where the home screen claims
/// nine items and the next tab lists three is a demo that teaches the reader
/// the two screens are unrelated.
class DashboardSummary {
  const DashboardSummary({
    required this.itemCount,
    required this.categoryCount,
    required this.completedCount,
    this.itemsByCategory = const {},
  });

  /// Everything in the collection.
  final int itemCount;

  /// How many shelves those items fall on.
  final int categoryCount;

  /// How many of [itemCount] are finished — the numerator of the meter.
  final int completedCount;

  /// How the collection splits across its shelves, shelf name to count.
  ///
  /// A map rather than a list of pairs because that is what the endpoint
  /// returns and what a caller reads by name. Empty is a legitimate value —
  /// a collection with one shelf has nothing to compare — and the dashboard
  /// draws the comparison only when there is one to draw.
  final Map<String, int> itemsByCategory;

  /// Finished over total, as a proportion, safe on an empty collection.
  ///
  /// Guarded here rather than at the call site because a division by zero in
  /// a layout does not throw, it produces `NaN`, and a `NaN` width fails an
  /// assertion three frames later in a widget that has nothing to do with it.
  double get completedFraction =>
      itemCount == 0 ? 0 : completedCount / itemCount;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        categoryCount: (json['categoryCount'] as num?)?.toInt() ?? 0,
        completedCount: (json['completedCount'] as num?)?.toInt() ?? 0,
        itemsByCategory: <String, int>{
          for (final entry
              in (json['itemsByCategory'] as Map<String, dynamic>? ?? const {})
                  .entries)
            entry.key: (entry.value as num?)?.toInt() ?? 0,
        },
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'itemCount': itemCount,
    'categoryCount': categoryCount,
    'completedCount': completedCount,
    'itemsByCategory': itemsByCategory,
  };
}
