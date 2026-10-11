part of 'roles_page.dart';

class _RoleExcelPage extends StatefulWidget {
  const _RoleExcelPage();
  @override
  State<_RoleExcelPage> createState() => _RoleExcelPageState();
}

class _RoleExcelPageState extends State<_RoleExcelPage> {
  List<ManagedRole> _rows = [];
  String? _error;
  bool _reading = false;

  Future<void> _pick() async {
    if (_reading) return;
    setState(() {
      _reading = true;
      _error = null;
      _rows = [];
    });
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['xlsx'], withData: true);
      if (result == null || !mounted) return;
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024 || file.bytes == null) {
        throw const FormatException('فایل xlsx باید کمتر از ۵ مگابایت باشد.');
      }
      final workbook = Excel.decodeBytes(file.bytes!);
      if (workbook.tables.isEmpty) {
        throw const FormatException('فایل خالی است.');
      }
      final rows = workbook.tables.values.first.rows;
      if (rows.isEmpty || rows.length > 501) {
        throw const FormatException('حداکثر ۵۰۰ نقش در هر فایل مجاز است.');
      }
      String cell(List<Data?> row, int index) =>
          index >= 0 && index < row.length
              ? (row[index]?.value?.toString() ?? '').trim()
              : '';
      final header = rows.first
          .map((item) => (item?.value?.toString() ?? '').trim().toLowerCase())
          .toList();
      for (final key in ['code', 'title', 'category']) {
        if (header.where((item) => item == key).length != 1) {
          throw FormatException('ستون الزامی یا تکراری: $key');
        }
      }
      String value(List<Data?> row, String key) =>
          cell(row, header.indexOf(key));
      final parsed = [
        for (final row in rows.skip(1))
          if (row
              .any((item) => (item?.value?.toString() ?? '').trim().isNotEmpty))
            ManagedRole(
                code: value(row, 'code').toUpperCase(),
                title: value(row, 'title'),
                category: value(row, 'category').toUpperCase(),
                parent: value(row, 'parent').toUpperCase(),
                description: value(row, 'description'),
                baseRoles: const []),
      ];
      if (!mounted) return;
      context.read<RoleCubit>().repository.validateImport(parsed);
      setState(() => _rows = parsed);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FormatException
            ? error.message
            : 'خواندن فایل اکسل ممکن نشد.');
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<RoleCubit, RoleState>(
      builder: (context, state) => Scaffold(
            appBar: const AsoudHeader(title: 'ورود نقش‌ها از اکسل'),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              const _RoleStatus(),
              const Text(
                  'ستون‌های الزامی: code، title، category\nاختیاری: parent، description\nدسته‌ها را ابتدا بسازید. نقش موجود بازنویسی نمی‌شود.'),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                  onPressed: _reading || state.saving ? null : _pick,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('انتخاب فایل اکسل')),
              if (_reading) const LinearProgressIndicator(),
              if (_error != null) _RoleHint(_error!, error: true),
              for (final role in _rows)
                ListTile(
                    title: Text(persianRoleLabel(role.title)),
                    subtitle: Text('${role.code} · ${role.category}'),
                    trailing: Text(role.parent)),
            ]),
            bottomNavigationBar: SafeArea(
                minimum: const EdgeInsets.all(16),
                child: FilledButton(
                    onPressed: _rows.isEmpty || _reading || state.saving
                        ? null
                        : () async {
                            final saved = await context
                                .read<RoleCubit>()
                                .importRoles(_rows);
                            if (saved && context.mounted) {
                              Navigator.pop(context, true);
                            }
                          },
                    child: const Text('ذخیره پیش‌نویس روی گوشی'))),
          ));
}
