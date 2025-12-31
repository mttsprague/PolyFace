# Admin System Setup Guide

## Overview
The PolyFace app now includes an admin system for managing group volleyball classes. Admins can create, open/close registration, and delete classes through a dedicated Admin tab.

## Firebase Setup

### 1. Grant Admin Access to a User

To make a user an admin, you need to add the `isAdmin` field to their user document in Firestore:

1. Open your Firebase Console: https://console.firebase.google.com/
2. Navigate to **Firestore Database**
3. Find the `users` collection
4. Locate the user document (by email or UID)
5. Click **Edit Document**
6. Add a new field:
   - **Field name**: `isAdmin`
   - **Type**: `boolean`
   - **Value**: `true`
7. Click **Save**

### 2. Firestore Security Rules

Add the following rules to your `firestore.rules` file to secure the classes collection:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ... existing rules ...
    
    // Classes collection
    match /classes/{classId} {
      // Anyone can read classes
      allow read: if true;
      
      // Only admins can create, update, or delete classes
      allow create, update, delete: if request.auth != null 
        && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      
      // Participants subcollection
      match /participants/{participantId} {
        // Anyone can read participants
        allow read: if true;
        
        // Users can register themselves
        allow create: if request.auth != null 
          && request.auth.uid == participantId;
        
        // Only admins can remove participants
        allow delete: if request.auth != null 
          && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.isAdmin == true;
      }
    }
  }
}
```

### 3. Deploy Security Rules

After updating your `firestore.rules` file:

```bash
cd PolyCal/functions  # or wherever your firebase.json is located
firebase deploy --only firestore:rules
```

## How It Works

### Admin Tab
- Once a user has `isAdmin: true` in their Firestore user document, they will see an **Admin** tab instead of the **More** tab
- The Admin tab provides:
  - **Create Class** button to add new classes
  - List of all upcoming classes with:
    - Open/Close registration toggle
    - Delete class button
    - Class details (capacity, registration status)

### Creating a Class
1. Tap **Create Class** in the Admin tab
2. Fill in:
   - **Title**: Class name (e.g., "Beginner Skills")
   - **Description**: What the class covers
   - **Date & Time**: When the class occurs
   - **Duration**: Length in minutes (default: 60)
   - **Max Participants**: Class capacity (default: 12)
   - **Location**: Where the class takes place
3. Tap **Create Class**
4. New class appears in the admin list as "Closed" (not open for registration)

### Opening Classes for Registration
1. Find the class in the Admin tab
2. Toggle the switch from **Closed** to **Open**
3. Class now appears in the **Book > Classes** tab for users
4. Class also appears in the **Home** screen "Upcoming Classes" section (top 3 upcoming)

### User Registration Flow
1. Users navigate to **Book** tab
2. Switch from "Lessons" to "Classes"
3. See all open classes with capacity information
4. Tap a class to view details
5. Tap **Register** button (if not full and not already registered)
6. Registration is added to Firestore with transaction to ensure capacity isn't exceeded

## Database Structure

### Classes Collection
Path: `/classes/{classId}`

```javascript
{
  id: "auto-generated",
  title: "Beginner Skills Class",
  description: "Learn fundamental volleyball skills...",
  startTime: Timestamp,
  endTime: Timestamp,
  maxParticipants: 12,
  currentParticipants: 0,
  location: "Midtown - 104 North Tuxedo Avenue",
  isOpenForRegistration: false,
  createdBy: "admin-user-id",
  createdAt: Timestamp
}
```

### Participants Subcollection
Path: `/classes/{classId}/participants/{userId}`

```javascript
{
  userId: "user-id",
  displayName: "John Doe",
  email: "john@example.com",
  registeredAt: Timestamp
}
```

## Testing

### Test Admin Flow
1. Create a test user account
2. Add `isAdmin: true` to their user document
3. Sign in with that account
4. Verify Admin tab appears
5. Create a test class
6. Open it for registration
7. Sign out

### Test User Flow
1. Sign in with a regular user account (no isAdmin field or isAdmin: false)
2. Verify More tab appears (not Admin)
3. Navigate to Book > Classes
4. Verify the test class appears
5. Tap to view details and register
6. Check that registration appears in Firestore

## Troubleshooting

### Admin tab not appearing
- Verify `isAdmin: true` is set in Firestore user document (case-sensitive)
- Sign out and sign back in to refresh the admin status
- Check Firebase Console > Authentication to confirm correct user

### Classes not appearing in Book tab
- Verify class has `isOpenForRegistration: true` in Firestore
- Check that `startTime` is in the future
- Ensure user is authenticated

### Registration failing
- Check Firestore security rules are deployed
- Verify class is not full (`currentParticipants < maxParticipants`)
- Ensure user is not already registered (check participants subcollection)
- Check browser/Xcode console for error messages

## Additional Notes

- **Concurrency Safety**: Registration uses Firestore transactions to prevent race conditions when multiple users register simultaneously
- **Capacity Management**: The system prevents registration when `currentParticipants >= maxParticipants`
- **Duplicate Prevention**: Users cannot register for the same class twice
- **Real-time Updates**: Classes list updates automatically when admins open/close registration

## Future Enhancements (Not Yet Implemented)
- Payment integration for class registration
- Waitlist when classes are full
- Email notifications for class updates
- Recurring class templates
- Attendance tracking
