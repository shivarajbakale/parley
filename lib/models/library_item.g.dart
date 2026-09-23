// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LibraryItem _$LibraryItemFromJson(Map<String, dynamic> json) => _LibraryItem(
  id: json['id'] as String,
  title: json['title'] as String,
  subtitle: json['subtitle'] as String,
  detail: json['detail'] as String,
  iconName: json['iconName'] as String? ?? 'star',
  category: json['category'] as String? ?? 'Guides',
  minutes: (json['minutes'] as num?)?.toInt() ?? 0,
  progress: (json['progress'] as num?)?.toDouble() ?? 0,
);

Map<String, dynamic> _$LibraryItemToJson(_LibraryItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'detail': instance.detail,
      'iconName': instance.iconName,
      'category': instance.category,
      'minutes': instance.minutes,
      'progress': instance.progress,
    };
