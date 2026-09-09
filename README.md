# SafeBoard — Gender-Aware Bus Seating Allocation System

**Student ID:** 28745  
**Institution:** NSBM Green University (BSc MIS Final Year Project)  
**Context:** Sri Lankan Public Transport System  

---

## 🚌 Project Purpose
In Sri Lanka's public bus transportation, unstructured first-come seating creates unsafe mixed-gender proximity, leading to sexual harassment risks for female passengers and unfair accusations for male passengers. 

**SafeBoard** is a rule-based, gender-aware passenger allocation system that assigns seats and standing positions dynamically based on:
1. Passenger gender & safety preferences
2. Mobility requirements
3. Door proximity constraints
4. Real-time bus occupancy & crowding thresholds
5. Opposite-gender seating proximity optimization

---

## 🎨 Three-Zone Bus Layout Architecture

1. **PRIORITY ZONE (Pink — `#C2185B`)**
   - **Location:** Rows 1-3 near the front door.
   - **Target:** Passengers with Safety Preference enabled or mobility needs (wheelchair/elderly/walking aid).
   - **Risk Score:** `0.05`

2. **GENERAL ZONE (Blue — `#1565C0`)**
   - **Location:** Rows 4-8 standard seating.
   - **Target:** Standard passengers, maintaining opposite-gender proximity buffer rules.
   - **Risk Score:** `0.10 - 0.40`

3. **STANDING LIMIT ZONE (Amber — `#EF9F27`)**
   - **Location:** Rear aisle standing positions (Max 18).
   - **Limits:** Soft warning at 80% capacity (`crowding_warning`), hard block at 100% capacity.
   - **Risk Score:** `0.50 - 0.80`

---

## 🚀 How to Run the App

1. Ensure Flutter SDK 3.29+ and Dart SDK are installed.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run code analysis:
   ```bash
   flutter analyze
   ```
4. Run unit and widget tests:
   ```bash
   flutter test
   ```
5. Launch app on connected Android device, emulator, or Chrome web:
   ```bash
   flutter run
   ```
6. Build release APK:
   ```bash
   flutter build apk --release
   ```

---

## 🔥 Firebase Backend & Cloud Functions Setup

1. **Firestore Collections Created:**
   - `passengers`
   - `bookings`
   - `routes`
   - `buses`
   - `seats`
   - `seat_allocations`
   - `journey_instances`
   - `incident_reports`
   - `allocation_rules`
   - `analytics_log`

2. **Cloud Function Endpoint:**
   - Endpoint: `POST /allocateSeat` (`functions/index.js`)
   - Implements the 11-step rule-based allocation algorithm.
