# Tactical Mesh Map & Marker Plotter 🗺️📍

> **Offline vector spatial grid, categorical emergency pins, water point plotting, road hazards, and real-time mesh marker synchronization.**

---

## 1. Tactical Spatial Grid

In total telecom collapse, commercial online satellite maps (Google Maps, Mapbox) fail completely.

NeighborNet features a lightweight, high-contrast, offline vector grid canvas that maps coordinates, bearings, and field markers with zero internet or tile downloads.

---

## 2. Marker Categories & Icons

Markers are categorized for rapid visual assessment in high-stress tactical environments:

| Category | Icon / Pin | Meaning |
|---|---|---|
| `water` | 💧 Blue Droplet | Potable drinking water point / well / filtration station |
| `medical` | 🏥 Red Cross | First aid station, field clinic, triage center |
| `shelter` | ⛺ Green Shelter | Community evacuation shelter / heated safe zone |
| `hazard` | ⚠️ Yellow Warning | Fallen power lines, gas leaks, road washouts, fires |
| `comms` | 📡 Purple Tower | Radio repeater, LoRa gateway, Wi-Fi web portal |
| `resource` | 📦 Orange Box | Food distribution point, generator charging stand |

---

## 3. Plotting & Updating Markers

1. In the NeighborNet app, click **Tactical Map**.
2. Click **Plot Marker** (or click directly on the interactive vector canvas).
3. Fill in:
   - **Marker Title**: e.g., `Town Square Water Well`.
   - **Category**: e.g., `Water Point`.
   - **Latitude / Longitude**: Enter GPS coordinates or use the grid cursor.
   - **Operational Details**: e.g., `100 GPM well active. Boil advisory in effect.`
4. Click **Broadcast Marker**.

---

## 4. Tombstones & Marker Deletion

When a hazard is cleared or a water point runs dry:
- The author can delete the marker.
- NeighborNet broadcasts a `MarkerDelete(id)` tombstone across the mesh.
- Receiving nodes purge the marker from their active SQLite database and update their map view in real-time.
