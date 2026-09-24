import 'package:flutter_test/flutter_test.dart';
import 'package:neighbornet_app/models/neighbornet_models.dart';
import 'package:neighbornet_app/services/neighbornet_bridge.dart';
import 'package:neighbornet_app/state/neighbornet_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Offline Forms & Micro-App Model Tests', () {
    test('FormFieldDef serializes to/from JSON correctly', () {
      final json = {
        'id': 'patient_tag',
        'label': 'Patient ID / Tag #',
        'field_type': 'text',
        'required': true,
        'options': ['Opt1', 'Opt2'],
        'default_value': 'TAG-001',
      };

      final field = FormFieldDef.fromJson(json);
      expect(field.id, 'patient_tag');
      expect(field.label, 'Patient ID / Tag #');
      expect(field.fieldType, 'text');
      expect(field.required, isTrue);
      expect(field.options, ['Opt1', 'Opt2']);
      expect(field.defaultValue, 'TAG-001');

      final serialized = field.toJson();
      expect(serialized['id'], 'patient_tag');
      expect(serialized['required'], isTrue);
    });

    test('FormSchema serializes to/from JSON with nested fields', () {
      final json = {
        'id': 'schema-triage-1',
        'title': 'Field Triage',
        'category': 'triage',
        'description': 'Disaster Medical Triage',
        'author_hash': 'abcdef0123456789',
        'author_nickname': 'Medic1',
        'created_at': 1700000000,
        'fields': [
          {
            'id': 'triage_color',
            'label': 'Triage Category',
            'field_type': 'select',
            'required': true,
            'options': ['Red', 'Yellow', 'Green', 'Black'],
            'default_value': 'Yellow',
          }
        ],
      };

      final schema = FormSchema.fromJson(json);
      expect(schema.id, 'schema-triage-1');
      expect(schema.title, 'Field Triage');
      expect(schema.category, 'triage');
      expect(schema.fields.length, 1);
      expect(schema.fields.first.options.length, 4);

      final outJson = schema.toJson();
      expect(outJson['title'], 'Field Triage');
      expect((outJson['fields'] as List).length, 1);
    });

    test('FormEntry serializes and parses data JSON correctly', () {
      final json = {
        'id': 'entry-9912',
        'schema_id': 'schema-triage-1',
        'author_hash': 'abcdef0123456789',
        'author_nickname': 'Medic1',
        'data_json': '{"patient_tag":"TAG-101","triage_color":"Red (Immediate)"}',
        'timestamp_sec': 1700000100,
        'signature_hex': 'deadbeef1234',
      };

      final entry = FormEntry.fromJson(json);
      expect(entry.id, 'entry-9912');
      expect(entry.schemaId, 'schema-triage-1');
      expect(entry.authorNickname, 'Medic1');
      expect(entry.signatureHex, 'deadbeef1234');

      final parsed = entry.parsedData;
      expect(parsed['patient_tag'], 'TAG-101');
      expect(parsed['triage_color'], 'Red (Immediate)');
    });
  });

  group('NeighborNetBridge Form Fallbacks', () {
    test('Bridge handles uninitialized form calls gracefully', () {
      final bridge = NeighborNetBridge();
      expect(bridge.getFormSchemas(), isEmpty);
      expect(bridge.getFormEntries('any_id'), isEmpty);
      expect(
        bridge.createFormSchema(
          title: 'Test',
          description: 'Desc',
          category: 'custom',
          fields: [],
        ),
        isNull,
      );
      expect(
        bridge.submitFormEntry('any_id', {'key': 'value'}),
        isNull,
      );
    });
  });

  group('NeighborNetState Form Management', () {
    test('Initial form schemas and entries collections are initialized safely', () {
      final state = NeighborNetState();
      expect(state.formSchemas, isEmpty);
      expect(state.getFormEntriesForSchema('schema-1'), isEmpty);
    });

    test('refreshFormSchemas and refreshFormEntries execute without crashing', () async {
      final state = NeighborNetState();
      await state.refreshFormSchemas();
      await state.refreshFormEntries('schema-1');
      expect(state.formSchemas, isEmpty);
    });
  });
}
