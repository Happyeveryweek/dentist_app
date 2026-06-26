import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/patient.dart';

class AppointmentPatientSearchDialog extends StatefulWidget {
  final List<Patient> patients;
  final Patient? selectedPatient;
  final bool isLoading;
  final ValueChanged<Patient> onPatientSelected;

  const AppointmentPatientSearchDialog({
    Key? key,
    required this.patients,
    this.selectedPatient,
    required this.isLoading,
    required this.onPatientSelected,
  }) : super(key: key);

  @override
  State<AppointmentPatientSearchDialog> createState() =>
      _AppointmentPatientSearchDialogState();
}

class _AppointmentPatientSearchDialogState
    extends State<AppointmentPatientSearchDialog> {
  final TextEditingController _searchController = TextEditingController();
  late List<Patient> _filteredPatients;

  @override
  void initState() {
    super.initState();
    _filteredPatients = List<Patient>.from(widget.patients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(String value) {
    final normalized = value.toLowerCase();
    setState(() {
      if (normalized.isEmpty) {
        _filteredPatients = List<Patient>.from(widget.patients);
      } else {
        _filteredPatients = widget.patients.where((patient) {
          final name = patient.name.toLowerCase();
          final phone = patient.mainPhone.toLowerCase();
          final pinyin = (patient.namePinyin ?? '').toLowerCase();
          final initials = (patient.nameInitials ?? '').toLowerCase();
          return name.contains(normalized) ||
              phone.contains(normalized) ||
              pinyin.contains(normalized) ||
              initials.contains(normalized);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF667eea).withValues(alpha: 0.1),
                width: 1),
          ),
          child: Column(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF667eea),
                      Color(0xFF764ba2),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_search,
                              color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '选择患者',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 18),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 16,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _searchController,
                        onChanged: _filter,
                        decoration: InputDecoration(
                          hintText: '搜索患者 (姓名/拼音/电话)',
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.search,
                                color: Color(0xFF667eea), size: 20),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 16),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: widget.isLoading
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('正在加载患者数据...'),
                                  ],
                                ),
                              )
                            : _filteredPatients.isEmpty
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.search_off,
                                            size: 48, color: Colors.grey),
                                        SizedBox(height: 16),
                                        Text('没有找到匹配的患者'),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: _filteredPatients.length,
                                    itemBuilder: (context, index) {
                                      final patient = _filteredPatients[index];
                                      return Card(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 6),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          onTap: () {
                                            widget.onPatientSelected(patient);
                                            Navigator.of(context).pop();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 14),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(patient.name),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        patient.mainPhone
                                                                .isEmpty
                                                            ? '暂无电话'
                                                            : patient.mainPhone,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  DateFormat('yyyy-MM-dd')
                                                      .format(
                                                          patient.updatedAt),
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
