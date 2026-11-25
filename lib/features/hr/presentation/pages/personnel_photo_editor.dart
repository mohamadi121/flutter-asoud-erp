part of 'personnel_page.dart';

Future<bool> _pickPersonnelPhoto(
    BuildContext context,
    PersonnelRepository repository,
    String personId,
    ImagePicker? picker) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(
        leading: const Icon(Icons.photo_library_outlined),
        title: const Text('انتخاب از گالری'),
        onTap: () => Navigator.pop(sheet, ImageSource.gallery),
      ),
      ListTile(
        leading: const Icon(Icons.photo_camera_outlined),
        title: const Text('گرفتن عکس'),
        onTap: () => Navigator.pop(sheet, ImageSource.camera),
      ),
    ])),
  );
  if (source == null || !context.mounted) return false;
  try {
    final picked = await (picker ?? ImagePicker()).pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null || !context.mounted) return false;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return false;
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      try {
        if (!context.mounted) return false;
        return await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _PersonnelPhotoEditor(
                image: frame.image,
                repository: repository,
                personId: personId,
              ),
            ) ??
            false;
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'باز کردن عکس ممکن نشد. دسترسی دوربین یا فایل را بررسی کنید.')),
      );
    }
    return false;
  }
}

class _PersonnelPhotoEditor extends StatefulWidget {
  const _PersonnelPhotoEditor({
    required this.image,
    required this.repository,
    required this.personId,
  });
  final ui.Image image;
  final PersonnelRepository repository;
  final String personId;

  @override
  State<_PersonnelPhotoEditor> createState() => _PersonnelPhotoEditorState();
}

class _PersonnelPhotoEditorState extends State<_PersonnelPhotoEditor> {
  final _capture = GlobalKey();
  late final ui.Image _image;
  double zoom = 1;
  double _startZoom = 1;
  Offset offset = Offset.zero;
  Offset _lastTouch = Offset.zero;
  int turns = 0;
  bool busy = false;
  String? error;
  late String _requestId = _newRequestId();

  String _newRequestId() => 'portrait-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    _image = widget.image.clone();
  }

  @override
  void dispose() {
    _image.dispose();
    super.dispose();
  }

  Size _fitted(double side) {
    final width = (turns.isEven ? _image.width : _image.height).toDouble();
    final height = (turns.isEven ? _image.height : _image.width).toDouble();
    final scale = side * zoom / (width < height ? width : height);
    return Size(width * scale, height * scale);
  }

  void _clamp(double side) {
    final size = _fitted(side);
    final x = ((size.width - side) / 2).clamp(0.0, double.infinity);
    final y = ((size.height - side) / 2).clamp(0.0, double.infinity);
    offset = Offset(offset.dx.clamp(-x, x), offset.dy.clamp(-y, y));
  }

  void _change(VoidCallback update, double side) => setState(() {
        update();
        _clamp(side);
        error = null;
        _requestId = _newRequestId();
      });

  Future<void> _save() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final boundary =
          _capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image =
          await boundary.toImage(pixelRatio: 512 / boundary.size.width);
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) throw StateError('تصویر آماده نشد.');
        await widget.repository.savePortrait(
            widget.personId,
            base64Encode(
                png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes)),
            _requestId);
      } finally {
        image.dispose();
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'ذخیره عکس تأیید نشد؛ اتصال و دسترسی را بررسی کنید یا دوباره تلاش کنید.';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !busy,
        child: Dialog(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(builder: (context, constraints) {
              final side = constraints.maxWidth.clamp(0.0, 250.0).toDouble();
              _clamp(side);
              final fitted = _fitted(side);
              final frame = turns.isEven ? fitted : fitted.flipped;
              return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const Icon(Icons.photo_camera_outlined,
                          color: _blue, size: 18),
                      const Expanded(
                          child: Text('ویرایش و برش عکس',
                              textAlign: TextAlign.center)),
                      IconButton(
                          tooltip: 'انصراف از ویرایش عکس',
                          onPressed: busy ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ]),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F2FD),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Center(
                          child: DecoratedBox(
                        position: DecorationPosition.foreground,
                        decoration: BoxDecoration(
                            border: Border.all(color: _blue),
                            borderRadius: BorderRadius.circular(10)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: GestureDetector(
                            onScaleStart: busy
                                ? null
                                : (event) {
                                    _startZoom = zoom;
                                    _lastTouch = event.localFocalPoint;
                                  },
                            onScaleUpdate: busy
                                ? null
                                : (event) => _change(() {
                                      zoom = (_startZoom * event.scale)
                                          .clamp(1.0, 4.0);
                                      offset +=
                                          event.localFocalPoint - _lastTouch;
                                      _lastTouch = event.localFocalPoint;
                                    }, side),
                            child: RepaintBoundary(
                                key: _capture,
                                child: SizedBox.square(
                                  dimension: side,
                                  child: ClipRect(
                                      child: OverflowBox(
                                    maxWidth: double.infinity,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                        offset: offset,
                                        child: RotatedBox(
                                          quarterTurns: turns,
                                          child: RawImage(
                                              image: _image,
                                              width: frame.width,
                                              height: frame.height,
                                              fit: BoxFit.fill),
                                        )),
                                  )),
                                )),
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 8),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('بزرگ‌نمایی'),
                          Text('${toPersianDigits((zoom * 100).round())}٪'),
                        ]),
                    Slider(
                        value: zoom,
                        min: 1,
                        max: 4,
                        onChanged: busy
                            ? null
                            : (value) => _change(() => zoom = value, side)),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                          tooltip: 'چرخش ۹۰ درجه به راست',
                          onPressed: busy
                              ? null
                              : () => _change(() {
                                    turns = (turns + 1) % 4;
                                    offset = Offset.zero;
                                  }, side),
                          icon: const Icon(Icons.rotate_right)),
                      IconButton(
                          tooltip: 'چرخش ۹۰ درجه به چپ',
                          onPressed: busy
                              ? null
                              : () => _change(() {
                                    turns = (turns + 3) % 4;
                                    offset = Offset.zero;
                                  }, side),
                          icon: const Icon(Icons.rotate_left)),
                      IconButton(
                          tooltip: 'بازنشانی برش',
                          onPressed: busy
                              ? null
                              : () => _change(() {
                                    turns = 0;
                                    zoom = 1;
                                    offset = Offset.zero;
                                  }, side),
                          icon: const Icon(Icons.restart_alt)),
                    ]),
                    if (error != null)
                      Text(error!,
                          style: const TextStyle(color: AsoudColors.danger)),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF111111)),
                      onPressed: busy ? null : _save,
                      child: Text(busy ? 'در حال ذخیره…' : 'تأیید و ذخیره عکس'),
                    ),
                  ]);
            }),
          ),
        )),
      );
}
