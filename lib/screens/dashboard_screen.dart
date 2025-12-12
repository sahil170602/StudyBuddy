// lib/screens/dashboard_screen.dart
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import 'account_settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _HourSlot {
  final TimeOfDay time;
  final String label;
  final String? eventText;
  bool done;
  _HourSlot({required this.time, required this.label, this.eventText, this.done = false});
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final ScrollController _mainScroll = ScrollController();

  // user profile (used by schedule generator)
  String _firstName = 'Learner';
  TimeOfDay? _wakeTime;
  int? _classStartHour;

  List<String> _importantNotifications = [
    'Exam schedule released — check dates',
    'Fee deadline approaching on 25th',
    'Library: new journals added',
  ];

  final Map<String, double> _curriculumProgress = {
    'Mathematics': 0.76,
    'Computer Science': 0.54,
    'Physics': 0.82,
    'Chemistry': 0.45,
    'English': 0.68,
  };

  final List<Map<String, dynamic>> _goals = [
    {'title': 'Finish Module 4', 'progress': 0.35},
    {'title': 'Submit Project Proposal', 'progress': 0.7},
    {'title': 'Read 5 research papers', 'progress': 0.2},
  ];

  DateTime _visibleMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  final Map<String, List<String>> _eventsByDate = {};

  int _newsItems = 40;
  bool _loadingMore = false;
  late final AnimationController _staggerController;
  String _selectedCategory = 'All';
  final List<String> _categories = ['All', 'Tech', 'University', 'Student Picks'];

  @override
  void initState() {
    super.initState();
    _mainScroll.addListener(_onMainScroll);
    final nowKey = _keyForDate(DateTime.now());
    _eventsByDate[nowKey] = ['Group meeting — 4:00 PM', 'Assignment 3 due (submit by 23:59)'];
    final tomorrowKey = _keyForDate(DateTime.now().add(const Duration(days: 1)));
    _eventsByDate[tomorrowKey] = ['Guest lecture: AI in Education - 10 AM'];
    _staggerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _mainScroll.removeListener(_onMainScroll);
    _mainScroll.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _onMainScroll() {
    if (_mainScroll.position.pixels > _mainScroll.position.maxScrollExtent - 220 && !_loadingMore) {
      setState(() => _loadingMore = true);
      Future.delayed(const Duration(milliseconds: 700), () {
        setState(() {
          _newsItems += 12;
          _loadingMore = false;
        });
      });
    }
  }

  String _keyForDate(DateTime d) => '${d.year}-${d.month}-${d.day}';

  List<DateTime> _daysInMonth(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0);
    return List.generate(last.day, (i) => DateTime(month.year, month.month, i + 1));
  }

  void _prevMonth() => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month - 1));
  void _nextMonth() => setState(() => _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + 1));
  void _selectDate(DateTime d) => setState(() => _selectedDate = d);
  void _addEventForSelected(String text) {
    final key = _keyForDate(_selectedDate);
    setState(() {
      final list = _eventsByDate.putIfAbsent(key, () => []);
      list.add(text);
    });
  }

  TimeOfDay? _parseEventTime(String text) {
    final regex1 = RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)', caseSensitive: false);
    final regex2 = RegExp(r'(\d{1,2})\s*(AM|PM|am|pm)', caseSensitive: false);
    final regex3 = RegExp(r'(\d{1,2}):(\d{2})');
    var m = regex1.firstMatch(text);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      final ap = m.group(3)!.toLowerCase();
      final hour = (ap == 'pm' && h < 12) ? h + 12 : (ap == 'am' && h == 12 ? 0 : h);
      return TimeOfDay(hour: hour % 24, minute: mm);
    }
    m = regex2.firstMatch(text);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final ap = m.group(2)!.toLowerCase();
      final hour = (ap == 'pm' && h < 12) ? h + 12 : (ap == 'am' && h == 12 ? 0 : h);
      return TimeOfDay(hour: hour % 24, minute: 0);
    }
    m = regex3.firstMatch(text);
    if (m != null) {
      final h = int.parse(m.group(1)!);
      final mm = int.parse(m.group(2)!);
      return TimeOfDay(hour: h % 24, minute: mm);
    }
    return null;
  }

  List<_HourSlot> generateDailySchedule(DateTime date) {
    final slots = <_HourSlot>[];
    for (var h = 6; h <= 23; h++) {
      slots.add(_HourSlot(time: TimeOfDay(hour: h, minute: 0), label: 'Free', eventText: null));
    }

    void setLabelAtHour(int h, String label, {String? event}) {
      final idx = slots.indexWhere((s) => s.time.hour == h);
      if (idx >= 0) slots[idx] = _HourSlot(time: slots[idx].time, label: label, eventText: event, done: false);
    }

    final wakeHour = _wakeTime?.hour ?? 7;
    final classHour = _classStartHour;

    setLabelAtHour(wakeHour, 'Wake up & Morning routine');
    final readyHour = (classHour != null) ? max(6, classHour - 1) : min(9, wakeHour + 1);
    setLabelAtHour(readyHour, 'Ready for school/college');

    setLabelAtHour(8, 'Breakfast / Prep');
    setLabelAtHour(12, 'Lunch / Short break');
    setLabelAtHour(15, 'Afternoon study / assignments');
    setLabelAtHour(18, 'Free time / Exercise');
    setLabelAtHour(19, 'Dinner');
    setLabelAtHour(20, 'Focused study / Projects');
    setLabelAtHour(22, 'Wind down / Relax');
    setLabelAtHour(23, 'Sleep');

    final events = _eventsByDate[_keyForDate(date)] ?? [];
    for (final e in events) {
      final tod = _parseEventTime(e);
      if (tod != null) {
        final hour = tod.hour;
        if (hour >= 6 && hour <= 23) {
          final idx = slots.indexWhere((s) => s.time.hour == hour);
          if (idx >= 0) {
            final existing = slots[idx];
            final label = (existing.label == 'Free') ? 'Event' : existing.label;
            slots[idx] = _HourSlot(time: existing.time, label: label, eventText: e, done: false);
          }
        } else {
          setLabelAtHour(20, 'Event: $e', event: e);
        }
      } else {
        final middayIdx = slots.indexWhere((s) => s.time.hour >= 11 && s.time.hour <= 14 && s.eventText == null);
        if (middayIdx >= 0) {
          slots[middayIdx] = _HourSlot(time: slots[middayIdx].time, label: 'Event', eventText: e, done: false);
        } else {
          setLabelAtHour(18, 'Event: $e', event: e);
        }
      }
    }

    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s.label == 'Free' && s.eventText == null) {
        final h = s.time.hour;
        if (h >= 9 && h < 12) {
          slots[i] = _HourSlot(time: s.time, label: 'Study / Course work', eventText: null);
        } else if (h >= 13 && h < 17) {
          slots[i] = _HourSlot(time: s.time, label: 'Practice / Assignments', eventText: null);
        } else if (h >= 17 && h < 19) {
          slots[i] = _HourSlot(time: s.time, label: 'Free / Short break', eventText: null);
        }
      }
    }

    return slots;
  }

  Future<void> _openAccountSettings() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AccountSettingsScreen()));
    setState(() {});
  }

  String _greetingForNow() {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'Good morning';
    if (h >= 12 && h < 17) return 'Good afternoon';
    if (h >= 17 && h < 21) return 'Good evening';
    return 'Good night';
  }

  Widget _glassProfileButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 6.0, sigmaY: 6.0),
        child: GestureDetector(
          onTap: _openAccountSettings,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(color: Colors.blueAccent.withOpacity(0.04), blurRadius: 10, spreadRadius: 1),
              ],
            ),
            child: Center(
              child: Icon(Icons.person, size: 20, color: Colors.white.withOpacity(0.95)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topHeader(BuildContext context) {
    final greeting = _greetingForNow();
    final displayName = _firstName.isEmpty ? 'Learner' : _firstName.split(' ').first;
    final today = '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: MultiColorPulsingText(
              '$greeting, Buddy $displayName',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          _glassProfileButton(),
        ]),
        const SizedBox(height: 6),
        Text(today, style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }

  Widget _importantNotificationsWidget() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _importantNotifications.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final txt = _importantNotifications[i];
          return SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.0, 0.08), end: Offset.zero)
                .animate(CurvedAnimation(parent: _staggerController, curve: Interval(0.0 + i * 0.05, min(0.9, 0.4 + i * 0.1), curve: Curves.easeOut))),
            child: GlassCard(
              child: SizedBox(
                width: 260,
                child: Row(children: [
                  const Padding(padding: EdgeInsets.all(12.0), child: Icon(Icons.priority_high, size: 28)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      const SizedBox(height: 0),
                      Text(txt, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Tap to view details', style: TextStyle(fontSize: 12, color: Colors.white70)),
                    ]),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _importantNotifications.removeAt(i))),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _curriculumAnalysis() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MultiColorPulsingText('Curriculum Analysis', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._curriculumProgress.entries.map((e) {
            final subject = e.key;
            final val = e.value.clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(subject)),
                  Text('${(val * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 6),
                Stack(children: [
                  Container(height: 8, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(6))),
                  FractionallySizedBox(widthFactor: val, child: Container(height: 8, decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.9), borderRadius: BorderRadius.circular(6)))),
                ]),
              ]),
            );
          }),
          const SizedBox(height: 4),
          Row(children: [
            ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.analytics_outlined), label: const Text('Deep Analysis')),
            const SizedBox(width: 12),
            TextButton(onPressed: () {}, child: const Text('Export CSV')),
          ])
        ]),
      ),
    );
  }

  Widget _annualProgress() {
    final avg = _curriculumProgress.values.fold(0.0, (p, n) => p + n) / max(1, _curriculumProgress.length);
    final percent = (avg).clamp(0.0, 1.0);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MultiColorPulsingText('Annual Progress', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Row(children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox(
                  width: 110,
                  height: 110,
                  child: CircularProgressIndicator(
                    value: percent,
                    strokeWidth: 10,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(percent * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Yearly', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ])
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _statChip(Icons.book, 'Completed', '${(_curriculumProgress.length)} modules'),
                  _statChip(Icons.hourglass_bottom, 'Avg Speed', '${(avg * 10).round()} hrs/week'),
                  _statChip(Icons.check_circle_outline, 'On track', '${(percent * 100).round()}%'),
                ])
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _statChip(IconData icon, String title, String value) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 12)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ])
        ]),
      ),
    );
  }

  Widget _goalsRow() {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _goals.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final g = _goals[i];
          final p = (g['progress'] as double).clamp(0.0, 1.0);
          return GlassCard(
            child: SizedBox(
              width: 240,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(g['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: p, minHeight: 8, backgroundColor: Colors.white12, valueColor: AlwaysStoppedAnimation(Colors.amberAccent)),
                const SizedBox(height: 8),
                Row(children: [
                  Text('${(p * 100).round()}%'),
                  const Spacer(),
                  TextButton(onPressed: () {}, child: const Text('Open')),
                ])
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _calendar() {
    final days = _daysInMonth(_visibleMonth);
    final lead = DateTime(_visibleMonth.year, _visibleMonth.month, 1).weekday - 1;
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
            Expanded(child: Center(child: Text('${_visibleMonth.year} — ${_monthName(_visibleMonth.month)}', style: const TextStyle(fontWeight: FontWeight.bold)))),
            IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            MultiColorPulsingText('Mon', style: const TextStyle(fontSize: 12)),
            MultiColorPulsingText('Tue', style: const TextStyle(fontSize: 12)),
            MultiColorPulsingText('Wed', style: const TextStyle(fontSize: 12)),
            MultiColorPulsingText('Thu', style: const TextStyle(fontSize: 12)),
            MultiColorPulsingText('Fri', style: const TextStyle(fontSize: 12)),
            MultiColorPulsingText('Sat', style: const TextStyle(fontSize: 12)),
            MultiColorPulsingText('Sun', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lead + days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.2),
              itemBuilder: (context, idx) {
                if (idx < lead) return const SizedBox.shrink();
                final d = days[idx - lead];
                final selected = d.year == _selectedDate.year && d.month == _selectedDate.month && d.day == _selectedDate.day;
                final events = _eventsByDate[_keyForDate(d)] ?? const [];
                return GestureDetector(
                  onTap: () => _selectDate(d),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: selected ? Colors.blueAccent.withOpacity(0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selected ? Colors.blueAccent.withOpacity(0.5) : Colors.white.withOpacity(0.02)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${d.day}', style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.w500)),
                        const Spacer(),
                        if (events.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.18), borderRadius: BorderRadius.circular(6)),
                            child: Text('${events.length} events', style: const TextStyle(fontSize: 10)),
                          )
                      ]),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            ElevatedButton.icon(onPressed: () => _addEventForSelected('New note ${DateTime.now().millisecondsSinceEpoch % 10000}'), icon: const Icon(Icons.add), label: const Text('Add event')),
            const SizedBox(width: 8),
            TextButton(onPressed: () => setState(() => _eventsByDate.remove(_keyForDate(_selectedDate))), child: const Text('Clear events')),
            const Spacer(),
            Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ])
        ]),
      ),
    );
  }

  Widget _dateEventsList() {
    final events = _eventsByDate[_keyForDate(_selectedDate)] ?? [];
    if (events.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No events for this date', style: TextStyle(color: Colors.white70)));
    return Column(
      children: events.map((e) {
        final tod = _parseEventTime(e);
        final timeLabel = tod != null ? '${tod.format(context)}' : 'Time not set';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: GlassCard(
            child: ListTile(
              title: Text(e),
              subtitle: Text(timeLabel),
              leading: const Icon(Icons.event_note_rounded),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTodaysSchedule() {
    final slots = generateDailySchedule(_selectedDate);
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 0),
          MultiColorPulsingText('Today\'s Schedule', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 260,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: slots.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, idx) {
                final s = slots[idx];
                final label = s.eventText != null ? '${s.label} — ${s.eventText}' : s.label;
                return Row(children: [
                  SizedBox(
                    width: 72,
                    child: Text('${s.time.format(context)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (s.eventText != null) Text('Event', style: TextStyle(fontSize: 12, color: Colors.orangeAccent.withOpacity(0.9))),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(s.done ? Icons.check_circle : Icons.radio_button_unchecked, color: s.done ? Colors.greenAccent : Colors.white54),
                    onPressed: () => setState(() => s.done = !s.done),
                  )
                ]);
              },
            ),
          ),
        ]),
      ),
    );
  }

  String _categoryForIndex(int i) {
    final r = i % 3;
    if (r == 0) return 'Tech';
    if (r == 1) return 'University';
    return 'Student Picks';
  }

  String _generateTitle(int i, String cat) {
    if (cat == 'Tech') {
      final list = ['AI tool speeds up grading', 'New open-source library released', 'Security vulnerability patch available'];
      return list[(i ~/ 3) % list.length];
    } else if (cat == 'University') {
      final list = ['Semester registration opens', 'Scholarship deadline near', 'Campus workshop this week'];
      return list[(i ~/ 3) % list.length];
    } else {
      final list = ['Top study hacks', 'How to get research credits', 'Student startup wins grant'];
      return list[(i ~/ 3) % list.length];
    }
  }

  String _generateSubtitle(int i, String cat) {
    final base = 'Short summary tailored for students — recommended.';
    return '$base [$cat]';
  }

  String _timeAgoForIndex(int i) {
    final minutes = (i * 7) % 60;
    final hours = (i * 3) % 24;
    if (hours > 0) return '${hours}h ago';
    return '${minutes}m ago';
  }

  Future<void> _refreshNews() async {
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() {
      _newsItems = 40;
    });
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (m >= 1 && m <= 12) return names[m - 1];
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final allIndices = List<int>.generate(_newsItems, (i) => i);
    final visibleIndices = allIndices.where((i) {
      final cat = _categoryForIndex(i);
      return _selectedCategory == 'All' ? true : cat == _selectedCategory;
    }).toList(growable: false);

    return SafeArea(
      child: CustomScrollView(
        controller: _mainScroll,
        slivers: [
          SliverToBoxAdapter(child: _topHeader(context)),
          SliverToBoxAdapter(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              Padding(padding: const EdgeInsets.only(left: 12.0, bottom: 8), child: MultiColorPulsingText('Important', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              _importantNotificationsWidget(),
            ]),
          ),

          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10), child: _buildTodaysSchedule())),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6),
              child: _curriculumAnalysis(),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6), child: _annualProgress()),
          ),

          SliverToBoxAdapter(
            child: Column(children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Align(alignment: Alignment.centerLeft, child: MultiColorPulsingText('Goals', style: const TextStyle(fontWeight: FontWeight.bold)))),
              const SizedBox(height: 8),
              _goalsRow(),
              const SizedBox(height: 12),
            ]),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(children: [
                Align(alignment: Alignment.centerLeft, child: MultiColorPulsingText('Calendar', style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 8),
                LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth > 900) {
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 2, child: _calendar()),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Column(children: [
                          GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                MultiColorPulsingText('Events on selected date', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                _dateEventsList()
                              ]),
                            ),
                          )
                        ]),
                      ),
                    ]);
                  } else {
                    return Column(children: [
                      _calendar(),
                      const SizedBox(height: 8),
                      GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            MultiColorPulsingText('Events on selected date', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _dateEventsList()
                          ]),
                        ),
                      ),
                    ]);
                  }
                }),
                const SizedBox(height: 12),
              ]),
            ),
          ),

          SliverPersistentHeader(
            pinned: true,
            delegate: _NewsHeaderDelegate(
              minExtent: 64,
              maxExtent: 64,
              title: 'News for you',
              categories: _categories,
              selected: _selectedCategory,
              onSelected: (val) => setState(() => _selectedCategory = val),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate((context, idx) {
              if (idx == visibleIndices.length) {
                if (_loadingMore) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: const [CircularProgressIndicator(), SizedBox(width: 12), Text('Loading more...')])),
                  );
                } else {
                  return const SizedBox(height: 80);
                }
              }

              final newsIndex = visibleIndices[idx];
              final category = _categoryForIndex(newsIndex);
              final title = _generateTitle(newsIndex, category);
              final subtitle = _generateSubtitle(newsIndex, category);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
                child: InkWell(
                  onTap: () {},
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    CircleAvatar(child: Text(category[0]), radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(subtitle, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 6),
                        Row(children: [
                          Text(_timeAgoForIndex(newsIndex), style: const TextStyle(fontSize: 11, color: Colors.white60)),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                            child: Text(category, style: const TextStyle(fontSize: 11)),
                          )
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.more_horiz), onPressed: () {}),
                  ]),
                ),
              );
            }, childCount: visibleIndices.length + 1),
          ),
        ],
      ),
    );
  }
}

class _NewsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtent;
  final double maxExtent;
  final String title;
  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  _NewsHeaderDelegate({
    required this.minExtent,
    required this.maxExtent,
    required this.title,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = overlapsContent || shrinkOffset > 0.0;
    final bgColor = pinned ? Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95) : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: bgColor,
      alignment: Alignment.centerLeft,
      child: Row(children: [
        // multicolour pulsing heading for news
        MultiColorPulsingText(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selected,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) {
                if (v != null) onSelected(v);
              },
              dropdownColor: Theme.of(context).scaffoldBackgroundColor,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ]),
    );
  }

  @override
  bool shouldRebuild(covariant _NewsHeaderDelegate oldDelegate) {
    return oldDelegate.title != title || oldDelegate.selected != selected || oldDelegate.maxExtent != maxExtent;
  }
}

/// MultiColorPulsingText: gradient-filled multicolour text + animated pulsing glow
class MultiColorPulsingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  final List<Color>? colors;
  final double minBlur;
  final double maxBlur;
  final double minAlpha;
  final double maxAlpha;

  const MultiColorPulsingText(
    this.text, {
    Key? key,
    this.style,
    this.duration = const Duration(milliseconds: 1600),
    this.colors,
    this.minBlur = 4.0,
    this.maxBlur = 18.0,
    this.minAlpha = 0.06,
    this.maxAlpha = 0.22,
  }) : super(key: key);

  @override
  State<MultiColorPulsingText> createState() => _MultiColorPulsingTextState();
}

class _MultiColorPulsingTextState extends State<MultiColorPulsingText> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  // default palette (nice multicolour)
  List<Color> get _defaultColors => [Colors.cyanAccent, Colors.blueAccent, Colors.purpleAccent, Colors.pinkAccent, Colors.amberAccent];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseStyle = widget.style ?? const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white);
    final colors = widget.colors ?? _defaultColors;

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final t = _anim.value;
        final blur = lerpDouble(widget.minBlur, widget.maxBlur, t)!;
        final alpha = lerpDouble(widget.minAlpha, widget.maxAlpha, t)!;
        final primaryGlow = Colors.white.withOpacity(alpha);
        final accentGlow = Colors.blueAccent.withOpacity(alpha * 0.85);

        // Use LayoutBuilder but guard against unbounded constraints.
        return LayoutBuilder(builder: (context, constraints) {
          // Compute a safe width and height to provide to the shader.
          double shaderWidth;
          double shaderHeight;

          // Attempt to compute text intrinsic width if constraints are unbounded
          final tp = TextPainter(
            text: TextSpan(text: widget.text, style: baseStyle),
            textDirection: TextDirection.ltr,
            maxLines: 1,
          )..layout();

          if (constraints.hasBoundedWidth && constraints.maxWidth.isFinite && constraints.maxWidth > 0) {
            shaderWidth = constraints.maxWidth;
          } else {
            // fallback: intrinsic text width + padding, limited to a reasonable max
            shaderWidth = tp.width + 24.0;
            if (shaderWidth.isNaN || shaderWidth <= 0) shaderWidth = 200.0;
            shaderWidth = shaderWidth.clamp(80.0, 900.0);
          }

          if (constraints.hasBoundedHeight && constraints.maxHeight.isFinite && constraints.maxHeight > 0) {
            shaderHeight = constraints.maxHeight;
          } else {
            // fallback height from textPainter or fontSize
            shaderHeight = tp.height;
            if (shaderHeight.isNaN || shaderHeight <= 0) shaderHeight = (baseStyle.fontSize ?? 16.0) * 1.4;
            shaderHeight = shaderHeight.clamp(14.0, 200.0);
          }

          // final safe rect
          final rect = Rect.fromLTWH(0, 0, shaderWidth, shaderHeight);

          final gradient = LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);

          return ShaderMask(
            shaderCallback: (r) {
              // shaderCallback gives `r` but we must use finite rect here.
              return gradient.createShader(rect);
            },
            blendMode: BlendMode.srcIn,
            child: Text(
              widget.text,
              style: baseStyle.copyWith(shadows: [
                Shadow(color: primaryGlow, blurRadius: blur),
                Shadow(color: accentGlow, blurRadius: blur * 1.25),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        });
      },
    );
  }
}
