import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../models/prescription.dart';

class PrescriptionHistoryScreen extends StatefulWidget {
  const PrescriptionHistoryScreen({super.key});

  @override
  State<PrescriptionHistoryScreen> createState() =>
      _PrescriptionHistoryScreenState();
}

class _PrescriptionHistoryScreenState extends State<PrescriptionHistoryScreen> {
  String _selectedFilter = 'All';
  List<Prescription> _allPrescriptions = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final result = await ApiService.getPrescriptionHistory();

    if (mounted) {
      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _allPrescriptions =
              data.map((json) => Prescription.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Failed to load history';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    List<Prescription> filteredPrescriptions = _allPrescriptions;

    if (_selectedFilter != 'All') {
      filteredPrescriptions = _allPrescriptions
          .where(
            (p) => p.status.toLowerCase() == _selectedFilter.toLowerCase(),
          )
          .toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription History'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          /// Dropdown Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  isExpanded: true,
                  dropdownColor: theme.colorScheme.surface,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: theme.colorScheme.primary,
                  ),
                  onChanged: (value) {
                    setState(() => _selectedFilter = value!);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text('All Prescriptions'),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text('Pending'),
                    ),
                    DropdownMenuItem(
                      value: 'verified',
                      child: Text('Verified'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          /// List or Empty State
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Text(_errorMessage,
                            style: const TextStyle(color: Colors.red)))
                    : filteredPrescriptions.isEmpty
                        ? Center(
                            child: Text(
                              'No prescriptions found',
                              style: GoogleFonts.roboto(
                                fontSize: 18,
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredPrescriptions.length,
                            itemBuilder: (context, index) {
                              return PrescriptionHistoryCard(
                                prescription: filteredPrescriptions[index],
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class PrescriptionHistoryCard extends StatelessWidget {
  final Prescription prescription;

  const PrescriptionHistoryCard({
    super.key,
    required this.prescription,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Prescription #${prescription.id.length > 8 ? prescription.id.substring(0, 8) : prescription.id}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: prescription.status.toLowerCase() == 'verified'
                        ? Colors.green.withValues(alpha: 0.1)
                        : Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    prescription.status.toUpperCase(),
                    style: TextStyle(
                      color: prescription.status.toLowerCase() == 'verified'
                          ? Colors.green
                          : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              prescription.date,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 10),
            if (prescription.imageUrl != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    prescription.imageUrl!,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: prescription.medications
                  .map(
                    (m) => Chip(
                      label: Text(
                        m,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      side: BorderSide(
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
