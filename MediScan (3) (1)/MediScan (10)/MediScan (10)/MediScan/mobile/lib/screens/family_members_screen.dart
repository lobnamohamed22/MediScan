import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;

  final List<String> _relationships = [
    'Father',
    'Mother',
    'Brother',
    'Sister',
    'Spouse',
    'Child',
    'Grandfather',
    'Grandmother',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _fetchFamilyMembers();
  }

  Future<void> _fetchFamilyMembers() async {
    try {
      final response = await ApiService.getFamilyMembers();
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _members = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching family members: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getRelationshipColor(String relation) {
    switch (relation.toLowerCase()) {
      case 'father':
        return Colors.blue[600]!;
      case 'mother':
        return Colors.purple[400]!;
      case 'brother':
        return Colors.indigo[400]!;
      case 'sister':
        return Colors.pink[400]!;
      case 'spouse':
        return Colors.red[400]!;
      case 'child':
        return Colors.teal[400]!;
      default:
        return Colors.blueGrey[400]!;
    }
  }

  IconData _getGenderIcon(String? gender) {
    if (gender == null) return Icons.person;
    if (gender.toLowerCase() == 'male') return Icons.male;
    if (gender.toLowerCase() == 'female') return Icons.female;
    return Icons.person;
  }

  Color _getGenderColor(String? gender) {
    if (gender == null) return Colors.grey;
    if (gender.toLowerCase() == 'male') return Colors.blueAccent;
    if (gender.toLowerCase() == 'female') return Colors.pinkAccent;
    return Colors.grey;
  }

  Future<void> _deleteMember(String memberId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Family Member'),
        content: Text('Are you sure you want to remove "$name" from your family profile completely?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      setState(() => _isLoading = true);
      try {
        final result = await ApiService.deleteFamilyMember(memberId);
        if (result['success'] == true) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Family member removed successfully')),
          );
          _fetchFamilyMembers();
        } else {
          messenger.showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to remove member')),
          );
          setState(() => _isLoading = false);
        }
      } catch (e) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Error communicating with server')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAddEditMemberDialog({Map<String, dynamic>? member}) {
    final isEdit = member != null;
    final nameCtrl = TextEditingController(text: isEdit ? member['member_name'] : '');
    final phoneCtrl = TextEditingController(text: isEdit ? (member['phone_number'] ?? '') : '');
    final dobCtrl = TextEditingController(text: isEdit ? (member['date_of_birth'] ?? '') : '');
    final notesCtrl = TextEditingController(text: isEdit ? (member['medical_conditions'] ?? '') : '');
    
    String selectedRelation = isEdit && _relationships.contains(member['relation'])
        ? member['relation']
        : 'Child';
    String selectedGender = isEdit && ['Male', 'Female'].contains(member['gender'])
        ? member['gender']
        : 'Male';
        
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Family Member' : 'Add Family Member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRelation,
                    decoration: const InputDecoration(labelText: 'Relationship'),
                    items: _relationships.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedRelation = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: ['Male', 'Female'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedGender = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: dobCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth (YYYY-MM-DD)',
                      hintText: 'e.g. 1995-12-25',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final regex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!regex.hasMatch(v)) return 'Use YYYY-MM-DD format';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Phone Number (Optional)'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Medical Notes (Optional)',
                      hintText: 'Allergies, chronic illness, daily meds...',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate() && mounted) {
                  Navigator.pop(context);
                  final messenger = ScaffoldMessenger.of(context);
                  setState(() => _isLoading = true);
                  
                  final payload = {
                    'name': nameCtrl.text.trim(),
                    'relation': selectedRelation,
                    'gender': selectedGender,
                    'dob': dobCtrl.text.trim(),
                    'phone_number': phoneCtrl.text.trim(),
                    'medical_conditions': notesCtrl.text.trim(),
                  };
                  
                  try {
                    Map<String, dynamic> result;
                    if (isEdit) {
                      result = await ApiService.updateFamilyMember(member['id'], payload);
                    } else {
                      result = await ApiService.addFamilyMember(payload);
                    }
                    
                    if (result['success'] == true) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(isEdit ? 'Family profile updated' : 'Family member added')),
                      );
                      _fetchFamilyMembers();
                    } else {
                      messenger.showSnackBar(
                        SnackBar(content: Text(result['message'] ?? 'Operation failed')),
                      );
                      setState(() => _isLoading = false);
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Error communicating with server')),
                    );
                    setState(() => _isLoading = false);
                  }
                }
              },
              child: Text(isEdit ? 'Save Changes' : 'Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Members'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => _showAddEditMemberDialog(),
          ),
        ],
      ),
      body: _isLoading && _members.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchFamilyMembers,
              child: _members.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      itemBuilder: (context, index) {
                        final member = _members[index];
                        return _buildMemberCard(member);
                      },
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 85, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No Family Members Listed',
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Add family members to quickly manage their prescriptions,\nmatching scans, and catalog orders.',
              textAlign: TextAlign.center,
              style: GoogleFonts.roboto(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add First Member'),
              onPressed: () => _showAddEditMemberDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final memberId = member['id']?.toString() ?? '';
    final name = member['member_name'] ?? 'Unknown Member';
    final relation = member['relation'] ?? 'Other';
    final gender = member['gender'] ?? 'Male';
    final dob = member['date_of_birth'] ?? 'N/A';
    final phone = member['phone_number'] ?? '';
    final notes = member['medical_conditions'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row title and relationship badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _getGenderIcon(gender),
                        color: _getGenderColor(gender),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRelationshipColor(relation).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    relation.toUpperCase(),
                    style: TextStyle(
                      color: _getRelationshipColor(relation),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Birthday & Gender
            Row(
              children: [
                const Icon(Icons.cake, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Date of Birth: $dob',
                  style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 14),
                ),
              ],
            ),
            
            // Phone Number (optional)
            if (phone.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    phone,
                    style: GoogleFonts.roboto(color: Colors.grey[300], fontSize: 14),
                  ),
                ],
              ),
            ],
            
            // Medical Notes (optional)
            if (notes.toString().trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Medical Alert / Notes:',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: GoogleFonts.roboto(fontSize: 13, color: Colors.grey[250]),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            
            // Bottom Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteMember(memberId, name),
                  tooltip: 'Remove Member',
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Profile'),
                  onPressed: () => _showAddEditMemberDialog(member: member),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
