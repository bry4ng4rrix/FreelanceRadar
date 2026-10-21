/// Page de résultats de l'API : `{"items": [...], "total", "page", "page_size"}`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;

  /// Nombre de pages (au moins 1 dès qu'il y a un résultat).
  int get pages => pageSize <= 0 ? 0 : (total + pageSize - 1) ~/ pageSize;

  bool get hasMore => page < pages;

  factory Paginated.fromJson(Object? json, T Function(Map<String, dynamic> item) itemFromJson) {
    final map = (json as Map).cast<String, dynamic>();
    final items = (map['items'] as List? ?? const [])
        .map((e) => itemFromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return Paginated(
      items: items,
      total: (map['total'] as num?)?.toInt() ?? items.length,
      page: (map['page'] as num?)?.toInt() ?? 1,
      pageSize: (map['page_size'] as num?)?.toInt() ?? items.length,
    );
  }

  static Paginated<T> empty<T>() =>
      Paginated<T>(items: const [], total: 0, page: 1, pageSize: 20);
}
