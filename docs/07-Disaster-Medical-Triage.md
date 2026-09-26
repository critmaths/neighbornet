# Disaster Medical Triage & Census Forms 🏥📋

> **Standardized field mass-casualty triage (START protocol), rapid shelter census, and decentralized custom form builders.**

---

## 1. Built-in Disaster Assessment Forms

NeighborNet seeds three standard emergency response forms by default:

### 1. Simple Triage & Rapid Treatment (START) Protocol
Used by CERT, first responders, and medics during mass casualty events:
- **Patient Tag #**: Field triage tag identifier.
- **Triage Color**:
  - **Red (Immediate)**: Respiratory rate > 30/min, Capillary refill > 2s, or unable to obey commands.
  - **Yellow (Delayed)**: Serious injuries; stable perfusion and respiration.
  - **Green (Minor)**: Walking wounded.
  - **Black (Expectant / Deceased)**: No spontaneous respiration after airway positioning.
- **Ambulatory Status**: Whether patient can walk.
- **Injury Description**: Trauma details, burn degree, fractures, hemorrhage.

### 2. Household & Shelter Wellness Census
Used during neighborhood welfare checks and shelter intake:
- **Household / Group Name**: Family or shelter identifier.
- **Safety Status**: `All Safe / OK`, `Minor Injuries`, `Critical / Trapped`, `Need Supplies / Power`.
- **People Count**: Total occupants (adults/children/elderly).
- **Shelter Address / Grid**: Physical location.
- **Immediate Rescue Required**: High-visibility flag for search-and-rescue teams.

### 3. Mutual Aid & Ration Distribution Ledger
Used at supply distribution hubs to prevent hoarding and log ration disbursements.

---

## 2. Dynamic Custom Form Schema Builder

Field leaders can create custom digital forms directly inside the app:

1. Navigate to **Community Forms** -> **Create Custom Form**.
2. Define the form title, category (`medical`, `census`, `logistics`, `damage`), and description.
3. Add fields of various types:
   - `text` — Names, descriptions, addresses.
   - `number` — Gallons dispensed, patient counts, temperature.
   - `select` — Categorical drop-downs.
   - `checkbox` — Boolean flags (e.g. `Has Power`, `Injuries Present`).
4. Click **Publish Form Schema to Mesh**.
5. All connected nodes will automatically receive the schema and render an interactive form interface.

---

## 3. Data Collection & Field Syncing

- Form submissions (`FormEntry`) are signed by the submitting node.
- Entries sync across the mesh to all reachable transport hubs.
- Data can be inspected in aggregate tables or exported to CSV/JSON for emergency operations centers (EOC).
