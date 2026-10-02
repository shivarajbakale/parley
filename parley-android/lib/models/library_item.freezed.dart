// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LibraryItem {

 String get id; String get title; String get subtitle;/// A longer blurb shown on the detail screen.
 String get detail;/// Icon *key*, not an [IconData] — icons have to survive JSON and a deep
/// link, and a codepoint is neither stable nor tree-shakeable. Resolved
/// through [libraryIcons] by [icon].
 String get iconName;/// Which shelf this belongs to. The Library's filter strip is built from
/// the distinct values present in the data, so adding a category is a
/// data change and not a screen change.
 String get category;/// How long the guide takes to read, in minutes.
///
/// Defaulted rather than required: a backend that does not send it still
/// decodes, and the detail screen says "Length not recorded" instead of
/// drawing a zero as though it were a fact.
 int get minutes;/// How far this reader has got, 0 to 1.
///
/// The reader's own state rather than the item's, and it lives here for
/// the same reason the demo has one model: a template that splits the
/// subject from the reader's place in it needs two repositories to show
/// one screen. A real app with a separate progress service reads it into
/// the same field.
 double get progress;
/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibraryItemCopyWith<LibraryItem> get copyWith => _$LibraryItemCopyWithImpl<LibraryItem>(this as LibraryItem, _$identity);

  /// Serializes this LibraryItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibraryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.iconName, iconName) || other.iconName == iconName)&&(identical(other.category, category) || other.category == category)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,subtitle,detail,iconName,category,minutes,progress);

@override
String toString() {
  return 'LibraryItem(id: $id, title: $title, subtitle: $subtitle, detail: $detail, iconName: $iconName, category: $category, minutes: $minutes, progress: $progress)';
}


}

/// @nodoc
abstract mixin class $LibraryItemCopyWith<$Res>  {
  factory $LibraryItemCopyWith(LibraryItem value, $Res Function(LibraryItem) _then) = _$LibraryItemCopyWithImpl;
@useResult
$Res call({
 String id, String title, String subtitle, String detail, String iconName, String category, int minutes, double progress
});




}
/// @nodoc
class _$LibraryItemCopyWithImpl<$Res>
    implements $LibraryItemCopyWith<$Res> {
  _$LibraryItemCopyWithImpl(this._self, this._then);

  final LibraryItem _self;
  final $Res Function(LibraryItem) _then;

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? subtitle = null,Object? detail = null,Object? iconName = null,Object? category = null,Object? minutes = null,Object? progress = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: null == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,iconName: null == iconName ? _self.iconName : iconName // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [LibraryItem].
extension LibraryItemPatterns on LibraryItem {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibraryItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibraryItem value)  $default,){
final _that = this;
switch (_that) {
case _LibraryItem():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibraryItem value)?  $default,){
final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String subtitle,  String detail,  String iconName,  String category,  int minutes,  double progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
return $default(_that.id,_that.title,_that.subtitle,_that.detail,_that.iconName,_that.category,_that.minutes,_that.progress);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String subtitle,  String detail,  String iconName,  String category,  int minutes,  double progress)  $default,) {final _that = this;
switch (_that) {
case _LibraryItem():
return $default(_that.id,_that.title,_that.subtitle,_that.detail,_that.iconName,_that.category,_that.minutes,_that.progress);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String subtitle,  String detail,  String iconName,  String category,  int minutes,  double progress)?  $default,) {final _that = this;
switch (_that) {
case _LibraryItem() when $default != null:
return $default(_that.id,_that.title,_that.subtitle,_that.detail,_that.iconName,_that.category,_that.minutes,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibraryItem extends LibraryItem {
  const _LibraryItem({required this.id, required this.title, required this.subtitle, required this.detail, this.iconName = 'star', this.category = 'Guides', this.minutes = 0, this.progress = 0}): super._();
  factory _LibraryItem.fromJson(Map<String, dynamic> json) => _$LibraryItemFromJson(json);

@override final  String id;
@override final  String title;
@override final  String subtitle;
/// A longer blurb shown on the detail screen.
@override final  String detail;
/// Icon *key*, not an [IconData] — icons have to survive JSON and a deep
/// link, and a codepoint is neither stable nor tree-shakeable. Resolved
/// through [libraryIcons] by [icon].
@override@JsonKey() final  String iconName;
/// Which shelf this belongs to. The Library's filter strip is built from
/// the distinct values present in the data, so adding a category is a
/// data change and not a screen change.
@override@JsonKey() final  String category;
/// How long the guide takes to read, in minutes.
///
/// Defaulted rather than required: a backend that does not send it still
/// decodes, and the detail screen says "Length not recorded" instead of
/// drawing a zero as though it were a fact.
@override@JsonKey() final  int minutes;
/// How far this reader has got, 0 to 1.
///
/// The reader's own state rather than the item's, and it lives here for
/// the same reason the demo has one model: a template that splits the
/// subject from the reader's place in it needs two repositories to show
/// one screen. A real app with a separate progress service reads it into
/// the same field.
@override@JsonKey() final  double progress;

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibraryItemCopyWith<_LibraryItem> get copyWith => __$LibraryItemCopyWithImpl<_LibraryItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibraryItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibraryItem&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.subtitle, subtitle) || other.subtitle == subtitle)&&(identical(other.detail, detail) || other.detail == detail)&&(identical(other.iconName, iconName) || other.iconName == iconName)&&(identical(other.category, category) || other.category == category)&&(identical(other.minutes, minutes) || other.minutes == minutes)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,subtitle,detail,iconName,category,minutes,progress);

@override
String toString() {
  return 'LibraryItem(id: $id, title: $title, subtitle: $subtitle, detail: $detail, iconName: $iconName, category: $category, minutes: $minutes, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$LibraryItemCopyWith<$Res> implements $LibraryItemCopyWith<$Res> {
  factory _$LibraryItemCopyWith(_LibraryItem value, $Res Function(_LibraryItem) _then) = __$LibraryItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String subtitle, String detail, String iconName, String category, int minutes, double progress
});




}
/// @nodoc
class __$LibraryItemCopyWithImpl<$Res>
    implements _$LibraryItemCopyWith<$Res> {
  __$LibraryItemCopyWithImpl(this._self, this._then);

  final _LibraryItem _self;
  final $Res Function(_LibraryItem) _then;

/// Create a copy of LibraryItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? subtitle = null,Object? detail = null,Object? iconName = null,Object? category = null,Object? minutes = null,Object? progress = null,}) {
  return _then(_LibraryItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,subtitle: null == subtitle ? _self.subtitle : subtitle // ignore: cast_nullable_to_non_nullable
as String,detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,iconName: null == iconName ? _self.iconName : iconName // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,minutes: null == minutes ? _self.minutes : minutes // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
