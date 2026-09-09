import 'package:flutter/material.dart';

import '../../../core/localization/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/child_task.dart';
import '../data/models/task_enums.dart';
import 'task_widgets.dart';

enum _CustomMode { dates, interval }

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The `recurrence_config` sub-form for `weekly` / `custom` tasks. Emits a
/// [RecurrenceConfig] built only from the backend-documented keys, plus a
/// validity flag (weekly needs ≥1 weekday; custom needs dates OR interval+anchor).
class RecurrenceField extends StatefulWidget {
  const RecurrenceField({
    super.key,
    required this.type,
    this.initial,
    required this.onChanged,
  });

  final TaskRecurrence type;
  final RecurrenceConfig? initial;
  final void Function(RecurrenceConfig config, bool isValid) onChanged;

  @override
  State<RecurrenceField> createState() => _RecurrenceFieldState();
}

class _RecurrenceFieldState extends State<RecurrenceField> {
  late Set<int> _daysOfWeek;
  late List<String> _dates;
  final _interval = TextEditingController();
  DateTime? _anchor;
  _CustomMode _mode = _CustomMode.dates;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;
    _daysOfWeek = {...?c?.daysOfWeek};
    _dates = [...?c?.dates];
    if (c?.intervalDays != null) {
      _interval.text = '${c!.intervalDays}';
      _anchor = DateTime.tryParse(c.anchorDate ?? '');
      _mode = _CustomMode.interval;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _emit());
  }

  @override
  void didUpdateWidget(RecurrenceField old) {
    super.didUpdateWidget(old);
    if (old.type != widget.type) _emit();
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  void _emit() {
    final config = switch (widget.type) {
      TaskRecurrence.weekly => RecurrenceConfig(
        daysOfWeek: _daysOfWeek.toList()..sort(),
      ),
      TaskRecurrence.custom =>
        _mode == _CustomMode.dates
            ? RecurrenceConfig(dates: [..._dates]..sort())
            : RecurrenceConfig(
                intervalDays: int.tryParse(_interval.text.trim()),
                anchorDate: _anchor == null ? null : _ymd(_anchor!),
              ),
      _ => const RecurrenceConfig(),
    };
    final valid = switch (widget.type) {
      TaskRecurrence.weekly => _daysOfWeek.isNotEmpty,
      TaskRecurrence.custom =>
        _mode == _CustomMode.dates
            ? _dates.isNotEmpty
            : (int.tryParse(_interval.text.trim()) ?? 0) > 0 && _anchor != null,
      _ => true,
    };
    widget.onChanged(config, valid);
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.type) {
      TaskRecurrence.weekly => _weekly(context),
      TaskRecurrence.custom => _custom(context),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _weekly(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(l.recurrenceWeekdays),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                label: Text(isoWeekdayShort(context, d)),
                selected: _daysOfWeek.contains(d),
                showCheckmark: false,
                selectedColor: AppColors.teal,
                onSelected: (sel) => setState(() {
                  sel ? _daysOfWeek.add(d) : _daysOfWeek.remove(d);
                  _emit();
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _custom(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<_CustomMode>(
          segments: [
            ButtonSegment(
              value: _CustomMode.dates,
              label: Text(l.recurrenceCustomModeDates),
            ),
            ButtonSegment(
              value: _CustomMode.interval,
              label: Text(l.recurrenceCustomModeInterval),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _emit();
          }),
        ),
        const SizedBox(height: 12),
        if (_mode == _CustomMode.dates) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final date in _dates)
                InputChip(
                  label: Text(date),
                  onDeleted: () => setState(() {
                    _dates.remove(date);
                    _emit();
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addDate,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l.recurrenceAddDate),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _interval,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l.recurrenceIntervalDays,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (_) => _emit(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DatePickTile(
            label: _anchor == null
                ? l.recurrenceAnchorDate
                : '${l.recurrenceAnchorDate}: ${formatTaskDate(context, _anchor!)}',
            onTap: _pickAnchor,
          ),
        ],
      ],
    );
  }

  Future<void> _addDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked == null) return;
    final ymd = _ymd(picked);
    if (!_dates.contains(ymd)) {
      setState(() {
        _dates.add(ymd);
        _emit();
      });
    }
  }

  Future<void> _pickAnchor() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) {
      setState(() {
        _anchor = picked;
        _emit();
      });
    }
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.navy,
      fontSize: 14,
      fontWeight: FontWeight.bold,
    ),
  );
}

class _DatePickTile extends StatelessWidget {
  const _DatePickTile({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_outlined,
              color: Color(0xFF8E98AC),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.navy)),
            ),
          ],
        ),
      ),
    );
  }
}
