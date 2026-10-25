/// Presentation-only index over native Department IDs. Never infers membership
/// or parentage from labels, positions, or list order.
class OrganizationUnitNavigation {
  OrganizationUnitNavigation(this.units);
  final List<Map<String, dynamic>> units;
  Map<String, dynamic>? byId(String? id) {
    for (final unit in units) {
      if (unit['name'] == id) return unit;
    }
    return null;
  }

  List<Map<String, dynamic>> children(String? id) => units
      .where((unit) => id == null
          ? byId(unit['parent_department'] as String?) == null
          : unit['parent_department'] == id)
      .toList();

  List<Map<String, dynamic>> path(String? id) {
    final result = <Map<String, dynamic>>[];
    final seen = <String>{};
    var current = byId(id);
    while (current != null && seen.add('${current['name']}')) {
      result.insert(0, current);
      current = byId(current['parent_department'] as String?);
    }
    return result;
  }

  Set<String> subtree(String id) {
    final result = <String>{id};
    var changed = true;
    while (changed) {
      final previous = result.length;
      for (final unit in units) {
        if (result.contains(unit['parent_department'])) {
          result.add('${unit['name']}');
        }
      }
      changed = result.length != previous;
    }
    return result;
  }

  List<Map<String, dynamic>> page(String? id, int index) =>
      children(id).skip(index * 4).take(4).toList();
}
