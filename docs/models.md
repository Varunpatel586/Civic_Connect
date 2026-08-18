# Civic Connect: Data Models

This document outlines the data model classes defined in `lib/models/`. These models handle parsing between raw JSON maps from Supabase and strongly-typed Dart objects.

---

## 1. UserProfile
Defined in [user_profile.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/models/user_profile.dart). Maps standard and administrative accounts from the `profiles` table.

### Fields
| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique database identifier (matches Supabase Auth UID) |
| `username` | `String` | Public display username |
| `email` | `String` | Registered email address |
| `role` | `String` | Role status (defaults to `'user'`, other value: `'admin'`) |
| `avatarUrl` | `String?` | Optional profile image link pointing to storage bucket |
| `createdAt` | `DateTime` | Date of registration |

### Methods
- **`UserProfile.fromJson(Map<String, dynamic> json)`**: Instantiates the class from a JSON object.
- **`toJson()`**: Returns a map representation of the profile for insert/update requests.

---

## 2. Issue
Defined in [issue.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/models/issue.dart). Maps civic complaints.

### Fields
| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique identifier (UUID string) |
| `userId` | `String` | Creator's ID (Foreign key) |
| `title` | `String` | Short summary title of the report |
| `description` | `String?` | Detailed complaint explanation |
| `imageUrl` | `String` | Public URL of captured photo |
| `latitude` | `double` | Precise GPS Latitude |
| `longitude` | `double` | Precise GPS Longitude |
| `timestamp` | `DateTime` | Captured time |
| `status` | `String` | State (`'Pending'`, `'In Progress'`, `'Resolved'`, `'Rejected'`) |
| `createdAt` | `DateTime` | Database entry insertion date |
| `agreeCount` | `int` | Total voters verifying this report is accurate |
| `disagreeCount`| `int` | Total voters disagreeing with the report details |
| `address` | `String?` | Reversed geocoded street address |
| `userVote` | `String?` | Vote state of the currently logged-in user (`'agree'`, `'disagree'`, or `null`) |

### Extensions
In [app_provider.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/providers/app_provider.dart), there is an extension `IssueVoteExtension` on the `Issue` class defining:
```dart
extension IssueVoteExtension on Issue {
  String? get userVote => null; // Placeholder for custom logic
}
```

---

## 3. Comment
Defined in [comment.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/models/comment.dart). Represents a user response under a specific issue.

### Fields
| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique comment ID |
| `issueId` | `String` | ID of the issue commented on |
| `userId` | `String` | ID of commenter |
| `content` | `String` | Text content of the comment |
| `createdAt` | `DateTime` | Date/time posted |
| `user` | `UserProfile` | Nested `UserProfile` representing the commenter |

---

## 4. Vote
Defined in [vote.dart](file:///E:/CODES/Mobile_Dev/Flutter/Civic_Connect/lib/models/vote.dart). Represents the database record of verification votes.

### Fields
| Field Name | Type | Description |
| :--- | :--- | :--- |
| `id` | `String` | Unique vote record ID |
| `issueId` | `String` | Target issue ID |
| `userId` | `String` | voter's user profile ID |
| `voteType` | `String` | Type classification |
| `createdAt` | `DateTime` | Date voted |
