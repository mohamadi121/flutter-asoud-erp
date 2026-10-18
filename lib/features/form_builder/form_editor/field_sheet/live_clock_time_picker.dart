import 'package:flutter/material.dart';

import '../../../../core/utils/jalali_date.dart';

class LiveClockTimePicker extends StatefulWidget {
  const LiveClockTimePicker({
    required this.initialTime,
    required this.minuteStep,
    required this.onConfirm,
    required this.onCancel,
    super.key,
  });

  final String? initialTime; // HH:mm
  final int minuteStep; // 5, 10, 15, 30
  final ValueChanged<String> onConfirm;
  final VoidCallback onCancel;

  @override
  State<LiveClockTimePicker> createState() => _LiveClockTimePickerState();
}

class _LiveClockTimePickerState extends State<LiveClockTimePicker> {
  late int selectedHour;
  late int selectedMinute;
  late FixedExtentScrollController hourController;
  late FixedExtentScrollController minuteController;
  late List<int> minutes;

  @override
  void initState() {
    super.initState();
    _initTime();
  }

  void _initTime() {
    final step = widget.minuteStep > 0 ? widget.minuteStep : 5;
    minutes = [for (var m = 0; m < 60; m += step) m];

    var h = 12;
    var m = 0;
    if (widget.initialTime != null && widget.initialTime!.contains(':')) {
      final parts = widget.initialTime!.split(':');
      h = int.tryParse(toLatinDigits(parts[0])) ?? 12;
      m = int.tryParse(toLatinDigits(parts[1])) ?? 0;
    } else {
      final now = DateTime.now();
      h = now.hour;
      m = now.minute;
    }

    selectedHour = h.clamp(0, 23);
    // Find closest minute in minutes list
    var closestM = minutes.first;
    var minDiff = 100;
    for (final cand in minutes) {
      final diff = (cand - m).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestM = cand;
      }
    }
    selectedMinute = closestM;

    hourController = FixedExtentScrollController(initialItem: selectedHour);
    final minIndex = minutes.indexOf(selectedMinute);
    minuteController = FixedExtentScrollController(initialItem: minIndex >= 0 ? minIndex : 0);
  }

  @override
  void dispose() {
    hourController.dispose();
    minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              Text(
                'ساعت',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B6478)),
              ),
              Text(
                'دقیقه',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5B6478)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                // Hours Wheel
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: hourController,
                    itemExtent: 36,
                    physics: const FixedExtentScrollPhysics(),
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    onSelectedItemChanged: (index) {
                      setState(() => selectedHour = index % 24);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: 24,
                      builder: (context, index) {
                        final isSelected = index == selectedHour;
                        return Center(
                          child: Text(
                            toPersianDigits(index.toString().padLeft(2, '0')),
                            style: TextStyle(
                              fontSize: isSelected ? 18 : 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF1876D2) : const Color(0xFF5B6478),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                // Minutes Wheel
                Expanded(
                  child: ListWheelScrollView.useDelegate(
                    controller: minuteController,
                    itemExtent: 36,
                    physics: const FixedExtentScrollPhysics(),
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    onSelectedItemChanged: (index) {
                      setState(() => selectedMinute = minutes[index % minutes.length]);
                    },
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: minutes.length,
                      builder: (context, index) {
                        final mVal = minutes[index];
                        final isSelected = mVal == selectedMinute;
                        return Center(
                          child: Text(
                            toPersianDigits(mVal.toString().padLeft(2, '0')),
                            style: TextStyle(
                              fontSize: isSelected ? 18 : 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? const Color(0xFF1876D2) : const Color(0xFF5B6478),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('انصراف', style: TextStyle(color: Color(0xFF5B6478))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final timeStr =
                        '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
                    widget.onConfirm(timeStr);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1876D2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('تأیید'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
