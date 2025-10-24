import 'package:flutter/material.dart';

class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback onSaveAndContinue;

  const ProfileSetupScreen({super.key, required this.onSaveAndContinue});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _cityController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();

  final List<Map<String, String>> countryCodes = [
    {'code': '+91', 'label': 'India'},
    {'code': '+1', 'label': 'United States'},
    {'code': '+44', 'label': 'United Kingdom'},
    {'code': '+61', 'label': 'Australia'},
    {'code': '+49', 'label': 'Germany'},
  ];
  String _selectedCountryCode = '+91';

  final List<String> _allInterests = [
    'Nature',
    'Art',
    'History',
    'Dogs',
    'Fitness',
    'Walking',
    'Photography',
    'Music',
    'Travel',
    'Food',
    'Technology',
    'Reading',
    'Yoga'
  ];
  final List<String> _selectedInterests = [];

  final TextEditingController _interestTextController = TextEditingController();

  @override
  void dispose() {
    _fullNameController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _interestTextController.dispose();
    super.dispose();
  }

  void _addInterest(String interest) {
    final trimmed = interest.trim();
    if (trimmed.isEmpty) return;
    if (!_selectedInterests.contains(trimmed)) {
      setState(() {
        _selectedInterests.add(trimmed);
      });
    }
    _interestTextController.clear();
  }

  void _removeInterest(String interest) {
    setState(() {
      _selectedInterests.remove(interest);
    });
  }

  void _onSaveAndContinue() {
    if (_formKey.currentState?.validate() ?? false) {
      final profile = {
        'fullName': _fullNameController.text.trim(),
        // etc...
      };

      debugPrint('Profile data: $profile');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Continuing...')),
      );

      widget.onSaveAndContinue();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fix validation errors.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFFA8D8B9);
    final accent = const Color(0xFFE0F2E9);
    final backgroundDark = const Color(0xFF112117);

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? backgroundDark
          : Colors.white,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {

          final isWide = constraints.maxWidth > 600;
          final horizontalPadding = isWide ? 48.0 : 16.0;
          final contentMaxWidth = isWide ? 720.0 : double.infinity;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: contentMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Header row with back icon, title
                    const SizedBox(height: 12),


                    Column(
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.photo_camera,
                            color: primary,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Add a friendly photo',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),

                    const SizedBox(height: 14),


                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [

                          _label('Full Name'),
                          const SizedBox(height: 6),
                          _buildTextField(
                            controller: _fullNameController,
                            hint: 'Enter your full name',
                            validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter your name'
                                : null,
                          ),

                          const SizedBox(height: 12),

                          isWide
                              ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _label('Age'),
                                    const SizedBox(height: 6),
                                    _buildTextField(
                                      controller: _ageController,
                                      hint: 'Enter your age',
                                      keyboardType: TextInputType.number,
                                      validator: (v) {
                                        if (v == null ||
                                            v.trim().isEmpty) {
                                          return 'Enter age';
                                        }
                                        final parsed =
                                        int.tryParse(v.trim());
                                        if (parsed == null ||
                                            parsed < 0 ||
                                            parsed > 120) {
                                          return 'Enter a valid age';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    _label('Your City'),
                                    const SizedBox(height: 6),
                                    _buildTextField(
                                      controller: _cityController,
                                      hint: 'Enter your city',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                              : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Age'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _ageController,
                                hint: 'Enter your age',
                                keyboardType: TextInputType.number,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Enter age';
                                  }
                                  final parsed = int.tryParse(v.trim());
                                  if (parsed == null ||
                                      parsed < 0 ||
                                      parsed > 120) {
                                    return 'Enter a valid age';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),
                              _label('Your City'),
                              const SizedBox(height: 6),
                              _buildTextField(
                                controller: _cityController,
                                hint: 'Enter your city',
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          _label('A little about you'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _bioController,
                            minLines: 4,
                            maxLines: 6,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? Colors.black12
                                  : accent,
                              hintText: 'Write a short bio...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),

                          const SizedBox(height: 12),

                          _label('Phone Number'),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness ==
                                      Brightness.dark
                                      ? Colors.black12
                                      : accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedCountryCode,
                                    items: countryCodes
                                        .map((e) => DropdownMenuItem<String>(
                                      value: e['code'],
                                      child: Text('${e['code']} ${e['label']}'),
                                    ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val == null) return;
                                      setState(() {
                                        _selectedCountryCode = val;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildTextField(
                                  controller: _phoneController,
                                  hint: 'Phone number',
                                  keyboardType: TextInputType.phone,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Enter phone number';
                                    }
                                    if (v.trim().length < 6) {
                                      return 'Enter valid phone';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          _label('What are your interests?'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? Colors.black12
                                  : accent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    for (final interest in _selectedInterests)
                                      Chip(
                                        label: Text(interest),
                                        deleteIcon: const Icon(Icons.close),
                                        onDeleted: () => _removeInterest(interest),
                                      ),

                                  ],
                                ),
                                const SizedBox(height: 8),


                                RawAutocomplete<String>(
                                  textEditingController: _interestTextController,
                                  focusNode: FocusNode(),
                                  optionsBuilder: (TextEditingValue textEditingValue) {
                                    if (textEditingValue.text == '') {

                                      return _allInterests.take(6).toList();
                                    }
                                    final input = textEditingValue.text.toLowerCase();
                                    return _allInterests.where((option) {
                                      return option.toLowerCase().contains(input) &&
                                          !_selectedInterests.contains(option);
                                    }).toList();
                                  },
                                  displayStringForOption: (option) => option,
                                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                    return TextField(
                                      controller: controller,
                                      focusNode: focusNode,
                                      decoration: InputDecoration(
                                        hintText: 'Type to add...',
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                      onSubmitted: (value) {
                                        _addInterest(value);
                                      },
                                    );
                                  },
                                  optionsViewBuilder: (context, onSelected, options) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 4.0,
                                        borderRadius: BorderRadius.circular(8),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxWidth: isWide ? 520 : double.infinity,
                                            maxHeight: 200,
                                          ),
                                          child: ListView.builder(
                                            padding: EdgeInsets.zero,
                                            shrinkWrap: true,
                                            itemCount: options.length,
                                            itemBuilder: (context, index) {
                                              final option = options.elementAt(index);
                                              return ListTile(
                                                title: Text(option),
                                                onTap: () {
                                                  onSelected(option);
                                                  _addInterest(option);
                                                },
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  onSelected: (selected) {
                                    // handled via optionsViewBuilder's onTap -> _addInterest
                                  },
                                ),

                                const SizedBox(height: 6),
                                const Text(
                                  'Pick from suggestions or type and press Enter to add.',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 18.0),
                      child: ElevatedButton(
                        onPressed: _onSaveAndContinue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Save and Continue',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                          color: Colors.white),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? Colors.black12
            : const Color(0xFFE0F2E9),
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
