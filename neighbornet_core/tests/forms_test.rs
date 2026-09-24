use std::thread;
use std::time::Duration;
use neighbornet_core::{FormFieldDef, NeighborNode};

#[test]
fn test_default_schemas_seeded_and_queryable() {
    let dir = tempfile::tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 47110, false).unwrap();

    let schemas = node.get_form_schemas();
    assert!(schemas.len() >= 4, "Expected at least 4 default schemas, got {}", schemas.len());

    let categories: Vec<String> = schemas.iter().map(|s| s.category.clone()).collect();
    assert!(categories.contains(&"triage".to_string()));
    assert!(categories.contains(&"logistics".to_string()));
    assert!(categories.contains(&"barter".to_string()));
    assert!(categories.contains(&"rollcall".to_string()));

    // Verify START triage fields
    let triage = schemas.iter().find(|s| s.id == "schema-med-triage-start").expect("Triage schema missing");
    assert_eq!(triage.title, "Disaster Medical Triage (START)");
    assert!(triage.fields.iter().any(|f| f.id == "triage_color"));
    assert!(triage.fields.iter().any(|f| f.id == "patient_tag"));
}

#[test]
fn test_create_custom_schema_and_submit_entries() {
    let dir = tempfile::tempdir().unwrap();
    let node = NeighborNode::new(dir.path().to_path_buf(), 47120, false).unwrap();

    // Create a custom micro-app schema: Water Well Quality Log
    let custom_fields = vec![
        FormFieldDef {
            id: "well_name".to_string(),
            label: "Well / Spring Identifier".to_string(),
            field_type: "text".to_string(),
            required: true,
            options: vec![],
            default_value: None,
        },
        FormFieldDef {
            id: "ph_level".to_string(),
            label: "Water pH (0-14)".to_string(),
            field_type: "number".to_string(),
            required: true,
            options: vec![],
            default_value: Some("7".to_string()),
        },
        FormFieldDef {
            id: "potable".to_string(),
            label: "Safe for Drinking".to_string(),
            field_type: "checkbox".to_string(),
            required: false,
            options: vec![],
            default_value: Some("true".to_string()),
        },
    ];

    let schema = node.create_form_schema(
        "Water Well Quality Monitor".to_string(),
        "Tracking community well potability and pH tests.".to_string(),
        "custom".to_string(),
        custom_fields,
    ).expect("Failed to create custom schema");

    assert!(schema.id.starts_with("schema-"));

    // Submit an entry
    let data_json = serde_json::json!({
        "well_name": "North Spring #2",
        "ph_level": "7.2",
        "potable": "true"
    }).to_string();

    let entry = node.submit_form_entry(schema.id.clone(), data_json.clone()).expect("Failed to submit entry");
    assert!(entry.id.starts_with("entry-"));
    assert_eq!(entry.schema_id, schema.id);
    assert!(!entry.signature_hex.is_empty());

    // Query entries
    let entries = node.get_form_entries(&schema.id);
    assert_eq!(entries.len(), 1);
    assert_eq!(entries[0].id, entry.id);
    assert_eq!(entries[0].data_json, data_json);
}

#[test]
fn test_mesh_form_and_entry_sync_between_nodes() {
    let dir_a = tempfile::tempdir().unwrap();
    let dir_b = tempfile::tempdir().unwrap();

    let node_a = NeighborNode::new(dir_a.path().to_path_buf(), 47130, false).unwrap();
    node_a.set_nickname("Medic Lead".to_string());

    let node_b = NeighborNode::new(dir_b.path().to_path_buf(), 47140, true).unwrap();
    node_b.set_nickname("Field Hospital Relay".to_string());

    node_a.connect_peer("127.0.0.1:47140".parse().unwrap());

    // Node A creates a triage entry
    let triage_data = serde_json::json!({
        "patient_tag": "TAG-8821",
        "triage_color": "Red (Immediate)",
        "can_walk": "false",
        "respirations": "Rapid (>30/min)",
        "perfusion": "Radial Pulse Present",
        "mental_status": "Follows Simple Commands",
        "location": "Sector 4 Rubble Pile",
        "chief_complaint": "Compound femur fracture and smoke inhalation"
    }).to_string();

    let triage_entry = node_a.submit_form_entry("schema-med-triage-start".to_string(), triage_data).unwrap();

    // Node B should receive the entry via mesh broadcast / sync
    let mut synced = false;
    for _ in 0..15 {
        thread::sleep(Duration::from_millis(400));
        let entries_on_b = node_b.get_form_entries("schema-med-triage-start");
        if entries_on_b.iter().any(|e| e.id == triage_entry.id) {
            synced = true;
            break;
        }
    }
    assert!(synced, "Node B failed to sync form entry from Node A over mesh DAG");
}
