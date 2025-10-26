import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DurationMinutePicker extends StatefulWidget {
  const DurationMinutePicker({super.key});

  @override
  State<DurationMinutePicker> createState() => _DurationMinutePickerState();
}

class _DurationMinutePickerState extends State<DurationMinutePicker> {
  int _selectedMinutes = 30; // default value

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(
                      const Color(0xFF6BCBA6),
                    ),
                  ),
                ),
                const Text(
                  'Select Duration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedMinutes),
                  child: const Text('Done'),
                  style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(
                      const Color(0xFF6BCBA6),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Picker
          Expanded(
            child: CupertinoPicker(
              scrollController: FixedExtentScrollController(
                initialItem: (_selectedMinutes ~/ 5) - 1,
              ),
              itemExtent: 40,
              onSelectedItemChanged: (index) {
                setState(() {
                  _selectedMinutes = (index + 1) * 5;
                });
              },
              children: List.generate(
                24, // 5 to 120 mins in 5-min steps
                (index) => Center(
                  child: Text(
                    '${(index + 1) * 5} min',
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
