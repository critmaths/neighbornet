# Rust Core Architecture & C FFI Reference 💻⚙️

> **Technical internals of `neighbornet_core`, the Dart FFI bridge, and the Web Gateway REST API schema.**

---

## 1. Native Rust Core Architecture (`neighbornet_core`)

```text
┌─────────────────────────────────────────────────────────────┐
│                    neighbornet_app (Flutter)                │
└──────────────────────────────┬──────────────────────────────┘
                               │ Dart FFI (`dart:ffi`)
┌──────────────────────────────v──────────────────────────────┐
│                  C FFI Layer (`src/lib.rs`)                 │
├─────────────────────────────────────────────────────────────┤
│                     NeighborNode (Arc<NodeInner>)           │
│  ├── reticulum-rs (Identity, Addressing, Signatures)        │
│  ├── rusqlite (SQLite Persistence: Messages, Bulletins)     │
│  ├── kiss & lora (Serial Framing & Packet Management)       │
│  └── web_gateway (Embedded Multi-Threaded HTTP & Captive AP)│
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Core C FFI Exported Functions

All C FFI functions use standard `extern "C"` calling conventions and memory management via `neighbornet_free_string`:

### Lifecycle & Status
- `neighbornet_init(data_dir, listen_port, is_transport) -> bool`
- `neighbornet_stop_node()`
- `neighbornet_get_status_json() -> *mut c_char`
- `neighbornet_set_nickname(name) -> bool`
- `neighbornet_free_string(ptr)`

### Messages & Bulletins
- `neighbornet_send_chat(channel, content) -> bool`
- `neighbornet_get_chat_history_json(channel) -> *mut c_char`
- `neighbornet_post_bulletin(title, content, urgency) -> bool`
- `neighbornet_get_bulletins_json() -> *mut c_char`

### Web Gateway & Captive Portal
- `neighbornet_start_web_gateway(port) -> *mut c_char`
- `neighbornet_stop_web_gateway() -> bool`
- `neighbornet_get_web_gateway_status_json() -> *mut c_char`

### Barter & Reputation
- `neighbornet_create_barter_listing(type, title, desc, cat, cond, seek, loc) -> *mut c_char`
- `neighbornet_get_barter_listings_json(cat_filter, type_filter) -> *mut c_char`
- `neighbornet_update_barter_status(listing_id, status) -> bool`
- `neighbornet_submit_barter_proposal(listing_id, offered, msg) -> *mut c_char`
- `neighbornet_get_proposals_for_listing_json(listing_id) -> *mut c_char`
- `neighbornet_submit_community_vouch(target_hash, rating, comment) -> *mut c_char`
- `neighbornet_get_vouches_for_node_json(target_hash) -> *mut c_char`

### Hardware LoRa Radio
- `neighbornet_list_serial_ports() -> *mut c_char`
- `neighbornet_connect_lora(port, baud, freq_hz, bw_hz, sf, cr) -> bool`
- `neighbornet_disconnect_lora() -> bool`
- `neighbornet_get_lora_status() -> *mut c_char`

### Duress & Mnemonic
- `neighbornet_panic_wipe() -> bool`
- `neighbornet_export_identity_mnemonic() -> *mut c_char`
- `neighbornet_restore_identity(mnemonic) -> *mut c_char`

---

## 3. Web Gateway REST API Schema

When the Web Gateway is active on port `8080`:

| Method | Path | Request Body | Response Body |
|---|---|---|---|
| `GET` | `/api/status` | — | `{"dest_hash":"...","nickname":"...","peer_count":...}` |
| `GET` | `/api/messages` | — | `[{"id":"...","sender_nickname":"...","content":"..."}]` |
| `POST` | `/api/messages` | `{"channel":"general","content":"..."}` | `{"status":"ok"}` |
| `GET` | `/api/bulletins` | — | `[{"id":"...","title":"...","urgency":"..."}]` |
| `POST` | `/api/bulletins` | `{"title":"...","content":"...","urgency":"..."}` | `{"status":"ok"}` |
| `GET` | `/api/barter` | — | `[{"id":"...","title":"...","seeking":"..."}]` |
| `POST` | `/api/barter` | `{"title":"...","seeking":"...","listing_type":"offer"}` | `BarterListing JSON` |
| `POST` | `/api/emergency` | — | `{"status":"emergency_broadcasted"}` |
