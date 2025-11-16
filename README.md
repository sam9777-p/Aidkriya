# 🏃‍♀️ aidKRIYA Walker App
**Serving Motion for the Nation**  
*A Flutter-powered platform connecting walkers and wanderers for wellness and social good.*

---

## 👥 Team Details
**Team Name:** localhost:6900  
**Members:**  
- Yashendra  
- Omkar Sanap  
- Samarth Agarwal  

---

## 📘 Table of Contents
1. [About the Project](#about-the-project)  
2. [App Concept](#app-concept)  
3. [Key Features](#key-features)  
4. [Technology Stack](#technology-stack)  
5. [Project Structure](#project-structure)  
6. [Installation & Setup](#installation--setup)  
7. [Firebase Configuration](#firebase-configuration)  
8. [Core Modules](#core-modules)  
9. [App Flow](#app-flow)  
10. [Screenshots (Optional)](#screenshots-optional)  
11. [How to Contribute](#how-to-contribute)  
12. [License & Credits](#license--credits)  
13. [Contact & Support](#contact--support)

---

## 🩵 About the Project
The **aidKRIYA Walker App** is a social wellness mobile application developed for the **Aidothon 4.0 - Walker App Challenge 2025** organized by the **Gita & Susil Kumar Das (GnSkD) Foundation**.  

It aims to connect **Walkers (companions)** and **Wanderers (users)** — promoting physical activity, combating loneliness, and enabling users to contribute to social causes with every walk.

> **Motto:** *"Serving Motion for the Nation"*

---

## 💡 App Concept
A **Walking Companion Platform for a Cause** — where every walk becomes an act of kindness.

- Wanderers can request nearby verified walkers for companionship.  
- Walkers can accept requests, coordinate, and accompany them.  
- Both enjoy a safe, meaningful, and trackable experience.

---

## ✨ Key Features
✅ **User Roles:**
- **Walker:** Verified companions who accept walk requests.  
- **Wanderer:** Individuals seeking safe, friendly walking partners.

✅ **Core Functionalities:**
- Google Sign-In Authentication  
- Real-Time Request & Acceptance  
- Firestore-based live updates for walk status  
- GPS Location Tracking (Live Map)  
- Payment Integration (Razorpay / UPI)  
- SOS / Emergency Alerts  
- Ratings & Reviews  
- Chat Module   
- Walk History & Analytics Dashboard  

✅ **Security & Trust:**
- Role-based access control  
- Verified profiles & ID validation  
- Background checks for Walkers  

---

## 🧰 Technology Stack
| Layer | Technology |
|-------|-------------|
| **Frontend** | Flutter (Dart) |
| **Backend** | Firebase Firestore, Firebase Authentication |
| **Payments** | Razorpay / UPI |
| **Maps** | Google Maps API |
| **Notifications** | Firebase Cloud Messaging |
| **State Management** | Provider / Riverpod |
| **Version Control** | GitHub (Private Repository) |

---

## 🗂 Project Structure
```
lib/
│
├── main.dart
├── screens/
│   ├── auth/
│   │   ├── sign_in_screen.dart
│   │   └── sign_up_screen.dart
│   ├── walker/
│   │   ├── walker_dashboard.dart
│   │   ├── active_walk_screen.dart
│   │   └── walk_summary_screen.dart
│   ├── wanderer/
│   │   ├── request_walk_screen.dart
│   │   └── walk_summary__screen.dart
│   │   └── payment__screen.dart
│   ├── common/
│   │   ├── profile_screen.dart
│   │   ├── walk_history_screen.dart
│
├── models/
│   ├── incoming_requests_model.dart
│   ├── walk_request.dart
│   └── walker_profile.dart
│
├── services/
│   ├── firestore_service.dart
│   ├── auth_service.dart
│   ├── payment_service.dart
│   └── location_service.dart
│
├── utils/
│   ├── constants.dart
│   └── helpers.dart
│
└── widgets/
    ├── custom_button.dart
    └── info_card.dart
```

---

## ⚙️ Installation & Setup
### 1️⃣ Prerequisites
- Flutter SDK (>=3.16)
- Android Studio or VS Code
- Firebase project setup
- Google Maps API key

### 2️⃣ Clone the Repository
```bash
git clone https://github.com/Aidothon2025/team-localhost-6900.git
cd aidkriya_walker_app
```

### 3️⃣ Install Dependencies
```bash
flutter pub get
```

### 4️⃣ Run the App
```bash
flutter run
```

---

## 🔥 Firebase Configuration
1. Create a Firebase project → [https://console.firebase.google.com](https://console.firebase.google.com)  
2. Add Android app package (e.g., `com.aidkriya.walker`)  
3. Download and place `google-services.json` inside `/android/app/`  
4. Enable:
   - Firebase Authentication (Google Sign-In)
   - Firestore Database
   - Cloud Storage
   - Cloud Messaging (optional)
5. Update Firestore Security Rules for role-based access.

---

## 📱 Core Modules

| Module | Description |
|--------|-------------|
| **Authentication** | Google Sign-In & Role verification |
| **Request Walk** | Wanderer requests nearby Walkers |
| **Match & Accept** | Walker views & accepts requests |
| **Live Tracking** | Real-time location sharing |
| **Walk Summary** | Distance, duration, and pace logged |
| **Payments** | Secure in-app transactions |
| **Ratings** | Both users rate each other post-walk |

---

## 🔄 App Flow 

1. **Login / Register via Google**  
   - Both Walkers and Wanderers authenticate using Google Sign-In.  
   - User roles are determined from Firestore (Walker or Wanderer).  

2. **Select Role → Walker / Wanderer**  
   - The user is directed to their respective dashboards.  
   - The app updates the user’s **online/offline status** in Firestore in real time.  

3. **Set Up Profile**  
   - Each user completes their profile with photo, age, gender, interests, preferred walking time, and location preferences.  
   - Walkers undergo verification before being visible for matching.  

4. **Request Phase (Wanderer → Walker)**  
   - A Wanderer can **send a walk request** to a nearby available Walker.  
   - If both are **online**, the request instantly appears on the Walker’s dashboard.  
   - If the Walker is **offline**, a **push notification** is sent via Firebase Cloud Messaging (FCM).  
   - Tapping the notification opens the app directly on the **Incoming Request Screen**, allowing the Walker to accept or decline the request.  

5. **Acceptance & Cancellation Logic**  
   - Once the Walker **accepts**, both users enter the “Ready to Walk” state.  
   - The **Walker** alone can start the walk (to ensure accountability).  
   - If the **Walker cancels** before or during the walk → The total **amount payable becomes ₹0** (no charge to Wanderer).  
   - If the **Wanderer cancels**, a **partial deduction** applies based on elapsed time (e.g., cancellation fee proportional to minutes booked).  
   - Both users receive in-app alerts and push notifications about acceptance, start, or cancellation events.  

6. **Real-Time Tracking**  
   - Once started by the Walker, both users can track live GPS locations on an embedded Google Map.  
   - The backend continuously logs **duration**, **distance**, and **status (active/completed)** in Firestore.  

7. **Walk Completion & Payment**  
   - The Walker ends the session once the walk is completed.  
   - Payment is automatically calculated and processed via Razorpay/UPI.  
   - Both parties are prompted to rate and review each other.  

8. **Post-Walk Summary**  
   - A detailed summary (date, distance, duration, total cost, and partner rating) is stored in **Walk History**.  
   - Users can view past walks and earnings (for Walkers) in their dashboards.
 
---

## 🖼 Screenshots 

Below are key screens from the **aidKRIYA Walker App**, organized in compact pairs for better readability.

<div align="center">

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/f191bf20-b538-45ce-8ecc-98e5b01f4929" width="220" alt="Home Screen" /></td>
    <td><img src="https://github.com/user-attachments/assets/35d9c106-16b8-40b8-9ca1-9b81364e1df6" width="220" alt="Incoming Request" /></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/ea3f3ac3-b3e8-4668-9c40-bf03b9804409" width="220" alt="Walk Request" /></td>
    <td><img src="https://github.com/user-attachments/assets/08d02351-7c0a-4653-9fef-96a0911c99b9" width="220" alt="Start Walk" /></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/4242477d-f5d2-41cb-a149-8533bd516b29" width="220" alt="Profile" /></td>
    <td><img src="https://github.com/user-attachments/assets/8826918d-06b3-4313-ae7c-991ba08cac2d" width="220" alt="Transition Screen" /></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/b0e11b77-685c-444f-a148-5cab35701353" width="220" alt="Walk Summary" /></td>
    <td><img src="https://github.com/user-attachments/assets/1a1c59f5-29d1-4139-ba3b-3ffa9b243dcb" width="220" alt="Active Walk" /></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/5fe94db6-0120-4cb1-9d00-e3c111c066eb" width="220" alt="Payment" /></td>
    <td><img src="https://github.com/user-attachments/assets/7a51c527-abe5-46fe-a3c4-b28626636edd" width="220" alt="Payment 1" /></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/18a5c592-79f2-4fbb-948a-07b9693f4cd0" width="220" alt="Payment 3" /></td>
    <td><img src="https://github.com/user-attachments/assets/67500977-3e2a-4b51-9202-d3c15b1b70d6" width="220" alt="UPI Screen" /></td>
  </tr>
</table>

</div>

```

---

## 🤝 How to Contribute
1. Fork this repository under [Aidothon2025 GitHub Org](https://github.com/orgs/Aidothon2025/repositories)  
2. Commit all changes to your private repo:
```bash
git add .
git commit -m "Initial submission"
git push origin main
```
3. Include this `README.md` and your Firebase setup instructions before the final submission.

---

## 📜 License & Credits
© 2025 **Gita & Susil Kumar Das (GnSkD) Foundation**  
aidKRIYA Walker App is developed under **Aidothon 4.0 - Walker App Challenge 2025**.

All rights reserved.  
Use permitted only for educational and non-commercial purposes as part of the challenge.

---

## 📩 Contact & Support
**📧** walker@aidkriya.com  
**🌐** [www.aidkriya.com](https://www.aidkriya.com)  
**📱** +91 98310 61039  
