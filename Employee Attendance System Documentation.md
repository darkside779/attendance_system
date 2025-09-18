Employee Attendance System Documentation
1. Executive Summary / Introduction
This document outlines the design and functionality of an employee attendance system developed using Flutter for the frontend and Firebase for the backend. The system aims to provide an efficient and secure method for tracking employee attendance through features such as facial recognition, geofencing, and a comprehensive admin dashboard. It supports multiple shifts and provides robust reporting capabilities.
2. Core Features
The system incorporates several key features to ensure accurate and reliable employee attendance tracking and management.
Authentication
Employees log in using Firebase Authentication (email/phone + password).
Admin panel access is managed with different privilege levels.
Face Recognition
Employee face data is registered and stored securely (e.g., in Firebase Storage or Firestore embeddings).
Facial validation is performed for both check-in and check-out processes.
Geofencing / Location Restriction
Attendance recording is restricted to employees within the defined company location radius (GPS check).
Company office coordinates are defined and stored in Firebase.
Attendance System
Provides a clear check-in and check-out mechanism.
Tracks total working minutes/hours per day.
Handles late arrivals and early leaves.
Supports multiple work shifts.
Admin Dashboard
Allows administrators to view detailed attendance logs.
Enables export of reports in various formats (CSV, PDF).
Provides tools to manage employees (add, remove, edit).
Facilitates tracking of absent and late employees.
3. Technical Architecture (Firebase)
The backend infrastructure of the system is built entirely on Firebase, leveraging its suite of services for scalability, security, and real-time data synchronization.
3.1 Firebase Services Overview
Auth: Used for secure employee and administrator login and user management.
Firestore: Serves as the primary NoSQL database for storing attendance records and user profiles.
Storage: Utilized for securely storing face images or related biometric data, if required.
Cloud Functions: Automates backend logic such as calculating working hours and detecting late/absent statuses.
Firebase Hosting (optional): Can be used to host the admin web dashboard.
Firebase Messaging: Powers push notifications for reminders and alerts.
3.2 Data Models (Firestore Collections)
/users Collection
This collection stores profiles for both employees and administrators.
userId: Unique identifier for the user.
name: Full name of the user.
email: User's email address.
role: Specifies user role (e.g., "employee" / "admin").
faceData: Stores embedding vector or a reference to face image data.
position: User's job position.
createdAt: Timestamp of user creation.
/attendance Collection
This collection records individual attendance entries.
attendanceId: Unique identifier for the attendance record.
userId: Reference to the user who made the attendance entry.
date: Date of attendance (e.g., 2025-09-13).
checkInTime: Timestamp of check-in.
checkOutTime: Timestamp of check-out.
totalMinutes: Calculated total working minutes for the session.
status: Attendance status (e.g., "present", "late", "absent").
/settings Collection
This collection stores company-wide settings.
companyId: Unique identifier for the company.
companyName: Name of the company.
allowedLocation: Geographic coordinates and radius defining the company's allowed attendance area ({lat, lng, radiusMeters}).
shifts: Configuration for various work shifts.
4. Application Structure (Flutter)
The frontend application is developed using Flutter, following a modular and organized file structure to ensure maintainability and scalability.
Plain Text
lib/
│
├── main.dart
│
├── core/
│   ├── constants/
│   │     location_constants.dart
│   │     app_strings.dart
│   ├── utils/
│   │     time_calculator.dart
│   │     location_checker.dart
│   │     face_recognition.dart
│
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── location_service.dart
│   ├── attendance_service.dart
│
├── models/
│   ├── user_model.dart
│   ├── attendance_model.dart
│
├── providers/ (if using Riverpod/Provider)
│   ├── auth_provider.dart
│   ├── attendance_provider.dart
│
├── screens/
│   ├── auth/
│   │     login_screen.dart
│   │     register_screen.dart
│   │
│   ├── employee/
│   │     home_screen.dart
│   │     check_in_screen.dart
│   │     history_screen.dart
│   │
│   ├── admin/
│   │     dashboard_screen.dart
│   │     employee_list_screen.dart
│   │     reports_screen.dart
│
├── widgets/
│   ├── custom_button.dart
│   ├── face_camera_widget.dart
│   ├── attendance_card.dart
5. Workflow and User Experience
This section details the typical interactions within the system from both employee and administrator perspectives.
5.1 Employee Workflow
Login: An employee opens the application and logs in using their email/phone credentials.
Check-In/Check-Out: The employee navigates to the Check-In Screen, which activates the camera for face scanning and performs a GPS location check.
Success: If the face matches and the employee is within the company's allowed location, the check-in/check-out time is recorded.
Failure: Otherwise, an appropriate error message is displayed.
Attendance Update: The attendance_service.dart calculates total minutes/hours worked and updates the corresponding Firestore record.
5.2 Admin Workflow
Dashboard Access: An administrator logs into the admin panel.
Report Viewing: The admin can view various attendance reports and logs through the dashboard.
Data Export: Reports can be exported in formats such as CSV or PDF for further analysis or record-keeping.
Employee Management: Admins have the capability to add, remove, or edit employee details and track absent or late employees.
6. Future Enhancements / Extras
Potential future additions to enhance the system's functionality and user experience include:
Push Notifications: Implement reminders for actions like checking out.
Offline Mode: Allow local storage of attendance data and synchronization when online connectivity is restored.
Calendar View: Provide employees with a calendar interface to review their attendance history.
Salary Calculation: Integrate weekly/monthly salary hour calculations based on attendance data.