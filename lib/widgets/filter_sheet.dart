import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/l10n.dart';
import '../services/profile_service.dart';

/// Bottom sheet for editing [SearchFilters]; pops with the new filters.
class FilterSheet extends StatefulWidget {
  final SearchFilters initial;
  const FilterSheet({super.key, required this.initial});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late SearchFilters f;
  late RangeValues _age;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    f = SearchFilters(
      minAge: i.minAge,
      maxAge: i.maxAge,
      district: i.district,
      education: i.education,
      maritalStatus: i.maritalStatus,
      diet: i.diet,
      country: i.country,
    );
    _age = RangeValues(i.minAge.toDouble(), i.maxAge.toDouble());
  }

  Widget _dd(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.tr(label)),
        items: [
          DropdownMenuItem<String>(value: null, child: Text(context.tr('Any'))),
          ...items.map(
            (e) => DropdownMenuItem(value: e, child: Text(context.tr(e))),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.tr('Age')}: ${_age.start.round()} - ${_age.end.round()}',
            ),
            RangeSlider(
              values: _age,
              min: 18,
              max: 70,
              divisions: 52,
              onChanged: (v) => setState(() => _age = v),
            ),
            _dd(
              'Native district',
              f.district,
              Options.tamilNaduDistricts,
              (v) => setState(() => f.district = v),
            ),
            _dd(
              'Education',
              f.education,
              Options.education,
              (v) => setState(() => f.education = v),
            ),
            _dd(
              'Marital status',
              f.maritalStatus,
              Options.maritalStatus,
              (v) => setState(() => f.maritalStatus = v),
            ),
            _dd(
              'Diet',
              f.diet,
              Options.diet,
              (v) => setState(() => f.diet = v),
            ),
            _dd(
              'Country',
              f.country,
              Options.countries,
              (v) => setState(() => f.country = v),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, SearchFilters()),
                    child: Text(context.tr('Reset')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      f.minAge = _age.start.round();
                      f.maxAge = _age.end.round();
                      Navigator.pop(context, f);
                    },
                    child: Text(context.tr('Apply')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
