/// The single system vocabulary of module keys, mirroring the backend
/// `asoud_erp/services/modules.py`. Every layer that names a module — workflow
/// definitions, document templates, request types and the offline preview —
/// uses these canonical keys and labels.
///
/// Earlier the workflow engine and the document templates each kept their own
/// list (`Accounting`/`Sales`/`Inventory`/`Support` vs `Finance`/`Selling`/
/// `Stock`/`Admin`), so a saved workflow had to be re-mapped by hand before it
/// reached the templates. This file is the one reference on the app side: the
/// legacy workflow keys are still readable (the live server sends them until
/// the backend is deployed) and resolve to their canonical key, while only
/// canonical keys are ever sent back.
library;

/// Canonical module keys, in the order the app should show them.
const moduleKeys = [
  'Finance',
  'Purchase',
  'Selling',
  'Stock',
  'HR',
  'Admin',
  'IT',
];

/// Canonical module key -> Persian label.
const moduleLabels = <String, String>{
  'Finance': 'مالی',
  'Purchase': 'خرید',
  'Selling': 'فروش',
  'Stock': 'انبار',
  'HR': 'منابع انسانی',
  'Admin': 'خدمات اداری',
  'IT': 'فناوری اطلاعات',
};

/// Legacy workflow-definition key -> canonical key. Both old vocabularies stay
/// readable: a stored or submitted legacy key resolves to its canonical key.
const legacyModuleKeys = <String, String>{
  'Accounting': 'Finance',
  'Sales': 'Selling',
  'Inventory': 'Stock',
  'Support': 'Admin',
};

/// Returns the canonical key for [key] (canonical or legacy), else `null`.
/// An empty or `null` key is not a module and returns `null`.
String? normalizeModuleKey(String? key) {
  if (key == null || key.isEmpty) return null;
  if (moduleLabels.containsKey(key)) return key;
  return legacyModuleKeys[key];
}

/// Persian label for a module key (canonical or legacy). An empty or `null`
/// key means "no module" and returns an empty string; any other unknown key
/// gets a Persian fallback so a raw English id never reaches the screen.
String moduleLabel(String? key) {
  if (key == null || key.isEmpty) return '';
  final canonical = normalizeModuleKey(key);
  if (canonical != null) return moduleLabels[canonical]!;
  return 'سایر';
}
