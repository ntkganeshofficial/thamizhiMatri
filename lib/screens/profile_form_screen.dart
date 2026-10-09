import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/app_theme.dart';
import '../core/constants.dart';
import '../core/l10n.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../widgets/photo_slots.dart';

/// Creates a profile (first login) or edits an existing one when [initial] is given.
class ProfileFormScreen extends StatefulWidget {
  final String uid;
  final Profile? initial;
  /// Admin creating or editing a profile on someone's behalf; the form then works on [uid], not the signed-in member.
  final String? managedBy;
  const ProfileFormScreen({
    super.key,
    required this.uid,
    this.initial,
    this.managedBy,
  });

  @override
  State<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends State<ProfileFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _occupation;
  late final TextEditingController _city;
  late final TextEditingController _about;
  late final TextEditingController _hobbies;
  final _phone = TextEditingController();
  late String _profileFor;
  RangeValues _prefAge = const RangeValues(18, 70);
  String? _prefEducation;
  String? _prefDistrict;
  final _prefOccupation = TextEditingController();
  bool _prefAnyAge = true;
  String? _gender;
  DateTime? _dob;
  double _height = 165;
  String? _marital;
  String? _education;
  String? _district;
  String? _country;
  String? _diet;
  late final List<PhotoSlot> _slots;
  bool _busy = false;

  bool get _editing => widget.initial != null;
  bool get _managed => widget.managedBy != null;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name);
    _occupation = TextEditingController(text: p?.occupation);
    _city = TextEditingController(text: p?.city);
    _about = TextEditingController(text: p?.about);
    _hobbies = TextEditingController(text: p?.hobbies);
    _prefAge = RangeValues(
      (p?.prefMinAge ?? 18).toDouble(),
      (p?.prefMaxAge ?? 70).toDouble(),
    );
    _prefEducation = p?.prefEducation;
    _prefDistrict = p?.prefDistrict;
    _prefOccupation.text = p?.prefOccupation ?? '';
    _prefAnyAge = (p?.prefMinAge ?? 18) == 18 && (p?.prefMaxAge ?? 70) == 70;
    _phone.text = widget.managedBy != null
        ? ''
        : context.read<AuthService>().currentUser?.phoneNumber ?? '';
    if (p != null) {
      context.read<ProfileService>().getPhone(p.uid).then((v) {
        if (v != null && mounted) _phone.text = v;
      });
    }
    _profileFor = p?.profileFor ?? 'Myself';
    _gender = p?.gender;
    _dob = p?.dob;
    _height = (p?.heightCm ?? 165).toDouble();
    _marital = p?.maritalStatus;
    _education = p?.education;
    _district = p?.nativeDistrict;
    _country = p?.country ?? 'India';
    _diet = p?.diet;
    _slots = [for (final url in p?.photos ?? const <String>[]) PhotoSlot.existing(url)];
  }

  @override
  void dispose() {
    _name.dispose();
    _occupation.dispose();
    _city.dispose();
    _about.dispose();
    _hobbies.dispose();
    _phone.dispose();
    _prefOccupation.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18, now.month, now.day),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _pickPhoto() async {
    if (_slots.length >= Profile.maxPhotos) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (mounted && _slots.length < Profile.maxPhotos) {
      setState(() => _slots.add(PhotoSlot.picked(file, bytes)));
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_dob == null) return _toast(context.trRead('Select date of birth'));
    setState(() => _busy = true);
    final service = context.read<ProfileService>();
    final failMsg = context.trRead('Could not save profile');
    final phoneVerified =
        !_managed && context.read<AuthService>().currentUser?.phoneNumber != null;
    try {
      // Upload new photos first so the saved profile only ever points at live files.
      final photoUrls = <String>[];
      for (final slot in _slots) {
        photoUrls.add(
          slot.url ??
              await service.uploadPhoto(
                widget.uid,
                slot.file!,
                adminUid: widget.managedBy,
              ),
        );
      }
      final profile = Profile(
        uid: widget.uid,
        name: _name.text.trim(),
        profileFor: _profileFor,
        gender: _gender!,
        dob: _dob!,
        heightCm: _height.round(),
        maritalStatus: _marital!,
        education: _education!,
        occupation: _occupation.text.trim(),
        nativeDistrict: _district!,
        city: _city.text.trim(),
        country: _country!,
        diet: _diet!,
        about: _about.text.trim(),
        hobbies: _hobbies.text.trim(),
        verified: phoneVerified,
        managedBy: widget.managedBy,
        prefMinAge: _prefAnyAge ? 18 : _prefAge.start.round(),
        prefMaxAge: _prefAnyAge ? 70 : _prefAge.end.round(),
        prefEducation: _prefEducation,
        prefDistrict: _prefDistrict,
        prefOccupation: _prefOccupation.text.trim().isEmpty ? null : _prefOccupation.text.trim(),
        photos: photoUrls,
      );
      await service.saveProfile(profile, isNew: !_editing);
      await service.savePhone(widget.uid, _phone.text.trim());
      for (final old in widget.initial?.photos ?? const <String>[]) {
        if (!photoUrls.contains(old)) service.deletePhotoByUrl(old);
      }
      if (mounted && (_editing || _managed)) Navigator.pop(context);
    } catch (e) {
      _toast('$failMsg: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Widget _dropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: context.tr(label)),
        items: items
            .map((e) => DropdownMenuItem(value: e, child: Text(context.tr(e))))
            .toList(),
        onChanged: onChanged,
        validator: (v) => v == null ? context.trRead('Required') : null,
      ),
    );
  }

  Widget _text(
    String label,
    TextEditingController c, {
    int maxLines = 1,
    int minLength = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: context.tr(label)),
        validator: (v) => (v == null || v.trim().length < minLength)
            ? context.trRead('Required')
            : null,
      ),
    );
  }

  Widget _optionalDropdown(
    String label,
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            _editing
                ? 'Edit profile'
                : _managed
                ? 'Add a profile'
                : 'Create your profile',
          ),
        ),
        actions: [
          if (!_editing && !_managed)
            IconButton(
              tooltip: context.tr('Logout'),
              icon: const Icon(Icons.logout),
              onPressed: () => context.read<AuthService>().signOut(),
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            PhotoSlotsRow(
              slots: _slots,
              onAdd: _pickPhoto,
              onRemove: (i) => setState(() => _slots.removeAt(i)),
            ),
            const SizedBox(height: 24),
            _dropdown(
              'Profile created for',
              _profileFor,
              Options.profileFor,
              (v) => setState(() => _profileFor = v!),
            ),
            _text('Name', _name),
            _dropdown(
              'Gender',
              _gender,
              Options.genders,
              (v) => setState(() => _gender = v),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: InkWell(
                onTap: _pickDob,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: context.tr('Date of birth'),
                  ),
                  child: Text(
                    _dob == null
                        ? context.tr('Select')
                        : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                  ),
                ),
              ),
            ),
            Text(
              '${context.tr('Height')}: ${_height.round()} ${context.tr('cm')}',
            ),
            Slider(
              value: _height,
              min: 130,
              max: 210,
              divisions: 80,
              onChanged: (v) => setState(() => _height = v),
            ),
            _dropdown(
              'Marital status',
              _marital,
              Options.maritalStatus,
              (v) => setState(() => _marital = v),
            ),
            _dropdown(
              'Education',
              _education,
              Options.education,
              (v) => setState(() => _education = v),
            ),
            _text('Occupation', _occupation),
            _dropdown(
              'Native district (Tamil Nadu)',
              _district,
              Options.tamilNaduDistricts,
              (v) => setState(() => _district = v),
            ),
            _text('Current city', _city),
            _dropdown(
              'Country',
              _country,
              Options.countries,
              (v) => setState(() => _country = v),
            ),
            _dropdown(
              'Diet',
              _diet,
              Options.diet,
              (v) => setState(() => _diet = v),
            ),
            _text(
              'About me / my expectations',
              _about,
              maxLines: 4,
              minLength: 20,
            ),
            _text('Hobbies & interests', _hobbies, minLength: 0),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: context.tr('Mobile number'),
                  helperText: context.tr(
                    'Shared only with members whose interest you accept',
                  ),
                  helperMaxLines: 2,
                ),
                validator: (v) => (v == null || v.trim().length < 8)
                    ? context.trRead('Required')
                    : null,
              ),
            ),
            const Divider(height: 32),
            Text(
              context.tr('Partner preferences'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('All partner preferences are optional'),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeThumbColor: AppColors.maroon,
              title: Text(context.tr('Any age')),
              value: _prefAnyAge,
              onChanged: (v) => setState(() => _prefAnyAge = v),
            ),
            if (!_prefAnyAge) ...[
              Text(
                '${context.tr('Age')}: ${_prefAge.start.round()} - ${_prefAge.end.round()}',
              ),
              RangeSlider(
                values: _prefAge,
                min: 18,
                max: 70,
                divisions: 52,
                onChanged: (v) => setState(() => _prefAge = v),
              ),
            ],
            _optionalDropdown(
              'Education',
              _prefEducation,
              Options.education,
              (v) => setState(() => _prefEducation = v),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                controller: _prefOccupation,
                decoration: InputDecoration(
                  labelText: context.tr('Occupation'),
                  hintText: context.tr('Any'),
                ),
              ),
            ),
            _optionalDropdown(
              'Location',
              _prefDistrict,
              Options.tamilNaduDistricts,
              (v) => setState(() => _prefDistrict = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      context.tr(_editing ? 'Save changes' : 'Create profile'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
