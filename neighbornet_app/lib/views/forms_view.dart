import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/neighbornet_models.dart';
import '../state/neighbornet_state.dart';

class FormsView extends StatefulWidget {
  final NeighborNetState? state;

  const FormsView({super.key, this.state});

  @override
  State<FormsView> createState() => _FormsViewState();
}

class _FormsViewState extends State<FormsView> {
  String _selectedCategory = 'all';
  FormSchema? _activeSchema;
  String _searchQuery = '';

  NeighborNetState _getState(BuildContext context) {
    if (widget.state != null) return widget.state!;
    try {
      return Provider.of<NeighborNetState>(context, listen: true);
    } catch (_) {
      return widget.state!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _getState(context);
    final allSchemas = state.formSchemas;

    final filteredSchemas = _selectedCategory == 'all'
        ? allSchemas
        : allSchemas.where((s) => s.category == _selectedCategory).toList();

    // Default to first schema if none selected or if active was removed
    if (_activeSchema == null && allSchemas.isNotEmpty) {
      _activeSchema = allSchemas.first;
    } else if (_activeSchema != null && !allSchemas.any((s) => s.id == _activeSchema!.id)) {
      _activeSchema = allSchemas.isNotEmpty ? allSchemas.first : null;
    }

    final activeEntries = _activeSchema != null
        ? state.getFormEntriesForSchema(_activeSchema!.id)
        : <FormEntry>[];

    final displayedEntries = _searchQuery.isEmpty
        ? activeEntries
        : activeEntries.where((e) {
            final text = '${e.authorNickname} ${e.dataJson}'.toLowerCase();
            return text.contains(_searchQuery.toLowerCase());
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_outlined, size: 22),
            SizedBox(width: 8),
            Text('Community Forms & Micro-Apps'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Forms & Entries',
            onPressed: () => state.refreshFormSchemas(),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create New Form Schema',
            onPressed: () => _showCreateSchemaDialog(context, state),
          ),
          if (_activeSchema != null)
            IconButton(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export Ledger (CSV / JSON)',
              onPressed: () => _showExportDialog(context, _activeSchema!, activeEntries),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 800;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Schema Catalog & Filter
                SizedBox(
                  width: 320,
                  child: _buildSchemaCatalog(context, filteredSchemas, state),
                ),
                const VerticalDivider(width: 1),
                // Right Column: Active Form Details, Entry Feed & Submit Action
                Expanded(
                  child: _buildActiveFormArea(context, _activeSchema, displayedEntries, state),
                ),
              ],
            );
          } else {
            return Column(
              children: [
                // Category Filter Bar
                _buildCategoryFilters(),
                // Schema Horizontal Selector
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: filteredSchemas.length,
                    itemBuilder: (context, index) {
                      final schema = filteredSchemas[index];
                      final isSelected = _activeSchema?.id == schema.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(_getCategoryIcon(schema.category), size: 18),
                          label: Text(schema.title),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _activeSchema = schema);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: _buildActiveFormArea(context, _activeSchema, displayedEntries, state),
                ),
              ],
            );
          }
        },
      ),
      floatingActionButton: _activeSchema != null
          ? FloatingActionButton.extended(
              onPressed: () => _showSubmitEntryDialog(context, _activeSchema!, state),
              icon: const Icon(Icons.edit_note),
              label: Text('Fill ${_activeSchema!.title}'),
            )
          : null,
    );
  }

  Widget _buildCategoryFilters() {
    final categories = [
      {'id': 'all', 'label': 'All Forms'},
      {'id': 'triage', 'label': 'Medical Triage'},
      {'id': 'logistics', 'label': 'Logistics & Rations'},
      {'id': 'barter', 'label': 'Mutual Aid / Barter'},
      {'id': 'rollcall', 'label': 'Roll-Call & Safety'},
      {'id': 'custom', 'label': 'Custom'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(cat['label']!),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCategory = cat['id']!);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSchemaCatalog(
    BuildContext context,
    List<FormSchema> schemas,
    NeighborNetState state,
  ) {
    return Column(
      children: [
        _buildCategoryFilters(),
        const Divider(height: 1),
        Expanded(
          child: schemas.isEmpty
              ? const Center(
                  child: Text('No form templates available in this category'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: schemas.length,
                  itemBuilder: (context, index) {
                    final schema = schemas[index];
                    final isSelected = _activeSchema?.id == schema.id;
                    final entryCount = state.getFormEntriesForSchema(schema.id).length;

                    return Card(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withAlpha(35)
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: isSelected
                            ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)
                            : BorderSide(color: Colors.white.withAlpha(20)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(schema.category).withAlpha(40),
                          child: Icon(
                            _getCategoryIcon(schema.category),
                            color: _getCategoryColor(schema.category),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          schema.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Text(
                          schema.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$entryCount entries',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        onTap: () {
                          setState(() => _activeSchema = schema);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildActiveFormArea(
    BuildContext context,
    FormSchema? schema,
    List<FormEntry> entries,
    NeighborNetState state,
  ) {
    if (schema == null) {
      return const Center(
        child: Text('Select a form schema from the catalog'),
      );
    }

    return Column(
      children: [
        // Schema Header Banner
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_getCategoryIcon(schema.category), color: _getCategoryColor(schema.category)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schema.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      schema.category.toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                schema.description,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Search & Filter Entries
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search submitted entries...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        setState(() => _searchQuery = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showSubmitEntryDialog(context, schema, state),
                    icon: const Icon(Icons.add),
                    label: const Text('New Entry'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Entries Feed / Data Table
        Expanded(
          child: entries.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 48, color: Colors.white.withAlpha(80)),
                      const SizedBox(height: 12),
                      const Text(
                        'No entries recorded in this ledger yet.',
                        style: TextStyle(color: Colors.white60),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _showSubmitEntryDialog(context, schema, state),
                        icon: const Icon(Icons.edit),
                        label: const Text('Submit First Record'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _buildEntryCard(context, schema, entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEntryCard(BuildContext context, FormSchema schema, FormEntry entry) {
    final parsed = entry.parsedData;
    final date = DateTime.fromMillisecondsSinceEpoch(entry.timestampSec * 1000);
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Author & Timestamp
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(50),
                  child: Text(
                    entry.authorNickname.isNotEmpty ? entry.authorNickname[0].toUpperCase() : 'N',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  entry.authorNickname,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${entry.authorHash.length >= 8 ? entry.authorHash.substring(0, 8) : entry.authorHash})',
                  style: TextStyle(color: Colors.white.withAlpha(120), fontSize: 11),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.green.withAlpha(90)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 12, color: Colors.greenAccent),
                      SizedBox(width: 4),
                      Text(
                        'DAG Signed',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            const Divider(height: 16),
            // Dynamic Key-Value grid
            ...schema.fields.map((field) {
              final val = parsed[field.id]?.toString() ?? '—';
              if (val.isEmpty) return const SizedBox.shrink();

              // Special styling for medical triage color tag
              if (field.id == 'triage_color') {
                Color tagColor = Colors.grey;
                if (val.contains('Red')) tagColor = Colors.redAccent;
                if (val.contains('Yellow')) tagColor = Colors.amber;
                if (val.contains('Green')) tagColor = Colors.greenAccent;
                if (val.contains('Black')) tagColor = Colors.black87;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Text('${field.label}: ', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagColor.withAlpha(50),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: tagColor),
                        ),
                        child: Text(
                          val,
                          style: TextStyle(color: tagColor, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(
                        field.label,
                        style: const TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        val,
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showSubmitEntryDialog(BuildContext context, FormSchema schema, NeighborNetState state) {
    final formKey = GlobalKey<FormState>();
    final formData = <String, dynamic>{};

    // Prepopulate default values
    for (final field in schema.fields) {
      if (field.defaultValue != null) {
        formData[field.id] = field.defaultValue;
      }
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(_getCategoryIcon(schema.category), color: _getCategoryColor(schema.category)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Submit Entry: ${schema.title}')),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: schema.fields.map((field) {
                        if (field.fieldType == 'checkbox') {
                          final currentVal = formData[field.id] == 'true' || formData[field.id] == true;
                          return SwitchListTile(
                            title: Text(field.label, style: const TextStyle(fontSize: 14)),
                            value: currentVal,
                            onChanged: (val) {
                              setModalState(() {
                                formData[field.id] = val.toString();
                              });
                            },
                          );
                        } else if (field.fieldType == 'select') {
                          final currentVal = formData[field.id] ?? (field.options.isNotEmpty ? field.options.first : null);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: currentVal,
                              decoration: InputDecoration(
                                labelText: field.label,
                                border: const OutlineInputBorder(),
                              ),
                              items: field.options.map((opt) {
                                return DropdownMenuItem(value: opt, child: Text(opt));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setModalState(() {
                                    formData[field.id] = val;
                                  });
                                }
                              },
                              validator: (val) {
                                if (field.required && (val == null || val.isEmpty)) {
                                  return '${field.label} is required';
                                }
                                return null;
                              },
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              initialValue: formData[field.id]?.toString(),
                              keyboardType: field.fieldType == 'number' ? TextInputType.number : TextInputType.text,
                              decoration: InputDecoration(
                                labelText: field.label,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (val) {
                                formData[field.id] = val;
                              },
                              validator: (val) {
                                if (field.required && (val == null || val.trim().isEmpty)) {
                                  return '${field.label} is required';
                                }
                                return null;
                              },
                            ),
                          );
                        }
                      }).toList(),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      final entry = await state.submitFormEntry(schema.id, formData);
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        if (entry != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Record submitted and signed across mesh DAG (ID: ${entry.id})'),
                              backgroundColor: Colors.green.shade800,
                            ),
                          );
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Submit Record'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCreateSchemaDialog(BuildContext context, NeighborNetState state) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String category = 'custom';
    final fields = <FormFieldDef>[
      FormFieldDef(id: 'field_1', label: 'Item Name', fieldType: 'text', required: true),
      FormFieldDef(id: 'field_2', label: 'Notes', fieldType: 'text', required: false),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Create New Community Form Schema'),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: 'Form Title',
                          hintText: 'e.g. Community Fuel Log, Medical Inventory',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(
                          labelText: 'Description / Purpose',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'triage', child: Text('Medical & Triage')),
                          DropdownMenuItem(value: 'logistics', child: Text('Logistics & Rations')),
                          DropdownMenuItem(value: 'barter', child: Text('Mutual Aid & Barter')),
                          DropdownMenuItem(value: 'rollcall', child: Text('Roll-Call & Safety')),
                          DropdownMenuItem(value: 'custom', child: Text('Custom Micro-App')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setModalState(() => category = val);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Fields Definition:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...fields.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final field = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    initialValue: field.label,
                                    decoration: InputDecoration(
                                      labelText: 'Field #${idx + 1} Label',
                                      isDense: true,
                                    ),
                                    onChanged: (val) {
                                      fields[idx] = FormFieldDef(
                                        id: 'field_${idx + 1}',
                                        label: val,
                                        fieldType: field.fieldType,
                                        required: field.required,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: field.fieldType,
                                  items: const [
                                    DropdownMenuItem(value: 'text', child: Text('Text')),
                                    DropdownMenuItem(value: 'number', child: Text('Number')),
                                    DropdownMenuItem(value: 'checkbox', child: Text('Checkbox')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        fields[idx] = FormFieldDef(
                                          id: field.id,
                                          label: field.label,
                                          fieldType: val,
                                          required: field.required,
                                        );
                                      });
                                    }
                                  },
                                ),
                                if (fields.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                    onPressed: () {
                                      setModalState(() => fields.removeAt(idx));
                                    },
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () {
                          setModalState(() {
                            final nextIdx = fields.length + 1;
                            fields.add(
                              FormFieldDef(
                                id: 'field_$nextIdx',
                                label: 'Field $nextIdx',
                                fieldType: 'text',
                                required: false,
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Field'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final state = context.read<NeighborNetState>();
                    final schema = await state.createFormSchema(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      category: category,
                      fields: fields,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      if (schema != null) {
                        setState(() => _activeSchema = schema);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Form schema "${schema.title}" published to Reticulum mesh DAG!'),
                            backgroundColor: Colors.green.shade800,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.cloud_upload),
                  label: const Text('Publish to Mesh'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showExportDialog(BuildContext context, FormSchema schema, List<FormEntry> entries) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Export ${schema.title} Ledger'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Copy as CSV'),
                subtitle: const Text('Compatible with Excel and incident command software'),
                onTap: () {
                  final header = ['Timestamp', 'Author', 'Hash', ...schema.fields.map((f) => f.label)].join(',');
                  final rows = entries.map((e) {
                    final p = e.parsedData;
                    final date = DateTime.fromMillisecondsSinceEpoch(e.timestampSec * 1000).toIso8601String();
                    final values = schema.fields.map((f) => '"${p[f.id]?.toString().replaceAll('"', '""') ?? ''}"');
                    return ['"$date"', '"${e.authorNickname}"', '"${e.authorHash}"', ...values].join(',');
                  }).join('\n');
                  final csv = '$header\n$rows';
                  Clipboard.setData(ClipboardData(text: csv));
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV copied to clipboard!')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Copy as JSON'),
                subtitle: const Text('Full raw JSON ledger array'),
                onTap: () {
                  final jsonStr = jsonEncode(entries.map((e) => e.toJson()).toList());
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'triage':
        return Icons.medical_services_outlined;
      case 'logistics':
        return Icons.water_drop_outlined;
      case 'barter':
        return Icons.swap_horiz_outlined;
      case 'rollcall':
        return Icons.people_outline;
      default:
        return Icons.assignment_outlined;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'triage':
        return Colors.redAccent;
      case 'logistics':
        return Colors.cyanAccent;
      case 'barter':
        return Colors.amberAccent;
      case 'rollcall':
        return Colors.lightGreenAccent;
      default:
        return Colors.orangeAccent;
    }
  }
}
