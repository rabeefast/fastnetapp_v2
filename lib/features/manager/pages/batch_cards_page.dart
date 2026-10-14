import 'package:flutter/material.dart';

import '../../../services/db_service.dart';

class BatchCardsPage extends StatefulWidget {
  final String batchId;
  final String batchName;

  const BatchCardsPage({
    super.key,
    required this.batchId,
    required this.batchName,
  });

  @override
  State<BatchCardsPage> createState() => _BatchCardsPageState();
}

class _BatchCardsPageState extends State<BatchCardsPage> {
  final _searchController = TextEditingController();
  late final Future<List<Map<String, dynamic>>> _cardsFuture;
  String _search = '';
  int _page = 0;

  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _cardsFuture = DbService().cardsInBatch(widget.batchId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.batchName)),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _cardsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child:
                  Text('تعذر تحميل جدول الكروت. تحقق من الاتصال والصلاحيات.'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allCards = snapshot.data!;
          final matching = allCards.where((card) {
            return _search.isEmpty ||
                (card['username']?.toString() ?? '').contains(_search.trim());
          }).toList();
          final pageCount = (matching.length / _pageSize).ceil();
          if (pageCount == 0) _page = 0;
          if (pageCount > 0 && _page >= pageCount) _page = pageCount - 1;
          final start = _page * _pageSize;
          final end = (start + _pageSize > matching.length)
              ? matching.length
              : start + _pageSize;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _searchController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'بحث باسم المستخدم',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _page = 0;
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                  onChanged: (value) => setState(() {
                    _search = value;
                    _page = 0;
                  }),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 700,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(child: _heading('الفئة')),
                              Expanded(child: _heading('التسلسل')),
                              Expanded(
                                flex: 2,
                                child: _heading('اسم المستخدم'),
                              ),
                              Expanded(child: _heading('الصفحة')),
                              Expanded(
                                flex: 2,
                                child: _heading('User Manager'),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: matching.isEmpty
                              ? const Center(child: Text('لا توجد كروت مطابقة'))
                              : ListView.separated(
                                  itemCount: end - start,
                                  separatorBuilder: (_, __) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final card = matching[start + index];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              card['categoryLabel']
                                                      ?.toString() ??
                                                  card['categoryKey']
                                                      ?.toString() ??
                                                  '—',
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${card['serial'] ?? '—'}',
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: SelectableText(
                                              card['username']?.toString() ??
                                                  '—',
                                              maxLines: 1,
                                            ),
                                          ),
                                          Expanded(
                                            child: Text(
                                              '${card['pageNumber'] ?? '—'}',
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(_routerStatus(card)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed:
                          _page > 0 ? () => setState(() => _page--) : null,
                      icon: const Icon(Icons.chevron_right),
                      tooltip: 'الصفحة السابقة',
                    ),
                    Text(
                      matching.isEmpty
                          ? '0 من 0'
                          : '${start + 1}–$end من ${matching.length}',
                    ),
                    IconButton(
                      onPressed: _page + 1 < pageCount
                          ? () => setState(() => _page++)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                      tooltip: 'الصفحة التالية',
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heading(String title) => Text(
        title,
        maxLines: 2,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
      );

  String _routerStatus(Map<String, dynamic> card) {
    if (card['um_found'] == false) return 'غير موجود';
    if (card['um_found'] == true && card['um_used'] == true) return 'مستخدم';
    if (card['um_found'] == true) return 'موجود';
    return 'لم تتم المزامنة';
  }
}
