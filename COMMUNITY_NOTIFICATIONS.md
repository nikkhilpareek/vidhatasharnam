# Community Notification System

## Overview
This system provides real-time notifications when admins post messages in community channels, including:
- Notification banner on homepage showing unread message count
- Badge on community tab in bottom navigation
- Automatic marking of messages as read when visiting community

## Components

### CommunityNotificationService
- Tracks unread messages from admin users
- Maintains user's last checked timestamp
- Provides real-time streams for UI updates

### UI Components
- Homepage banner showing latest admin messages
- Bottom navigation badge with unread count
- Auto-clear notifications when visiting community

## Firestore Collections Used

### user_community_state
```
{
  userId: string,
  lastChecked: timestamp
}
```

### channels (existing)
```
{
  name: string,
  members: [string],
  // ... other fields
}
```

### channels/{id}/messages (existing)  
```
{
  userId: string,
  text: string,
  createdAt: timestamp,
  // ... other fields
}
```

## Usage
The system automatically initializes when users log in and tracks admin messages in real-time. Users see notifications until they visit the community screen, which marks all messages as read.

## Security
- Only tracks messages from users with 'admin' role
- Users only see counts for channels they're members of
- No sensitive message content stored in notification state
