/// Strips markdown syntax to plain text for compact previews (list tile
/// subtitles, search snippets, etc). Not a full markdown parser — it covers the
/// syntax `AppFlowyEditor` emits: headings, bold/italic, inline code, lists,
/// blockquotes, links, images, and dividers.
String markdownToPlainText(String markdown) {
  if (markdown.isEmpty) return '';

  var out = markdown;

  // Images: ![alt](url) -> drop entirely (alt rarely useful in a preview).
  out = out.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '');

  // Links: [text](url) -> text
  out = out.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (m) => m[1] ?? '',
  );

  // Fenced code blocks: ```...``` -> contents only
  out = out.replaceAllMapped(
    RegExp(r'```[a-zA-Z]*\n?([\s\S]*?)```'),
    (m) => m[1] ?? '',
  );

  // Inline code: `foo` -> foo
  out = out.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m[1] ?? '');

  // Bold/italic: **foo** / __foo__ / *foo* / _foo_ -> foo
  out = out.replaceAllMapped(RegExp(r'(\*\*|__)(.+?)\1'), (m) => m[2] ?? '');
  out = out.replaceAllMapped(
    RegExp(r'(?<![*_])([*_])([^*_\n]+)\1(?![*_])'),
    (m) => m[2] ?? '',
  );

  // Line-leading syntax: headings, blockquotes, list markers, todo checkboxes,
  // and horizontal rules — strip the marker, keep the content.
  final lines = out.split('\n').map((line) {
    var l = line;
    l = l.replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s+'), '');
    l = l.replaceFirst(RegExp(r'^\s{0,3}>\s?'), '');
    l = l.replaceFirst(RegExp(r'^\s*[-*+]\s+\[[ xX]\]\s+'), '');
    l = l.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
    l = l.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
    if (RegExp(r'^\s*([-*_])\s*\1\s*\1[\s\1]*$').hasMatch(l)) l = '';
    return l;
  });

  // Collapse whitespace for a single-line-ish preview.
  return lines.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
