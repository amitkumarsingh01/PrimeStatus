# Admin Panel - Crafto

A comprehensive admin panel for managing the Crafto application with sidebar navigation and user management.

## Features

### 🎨 Image Editor
- Upload and edit images/videos
- Add text overlays with customizable fonts, colors, and positions
- Profile photo placement with background removal
- Business information overlays (address, phone)
- Save and publish posts to the gallery

### 👥 Users Management
- View all registered users
- Search users by name, email, or phone number
- Filter users by type (Business/Personal)
- View user details including:
  - Profile information
  - Contact details
  - Location information
  - Account type
  - Registration date
- Delete users (with confirmation)

### 📊 Dashboard
- Overview of admin activities
- Quick access to create new posts
- View existing posts with preview
- Manage post settings and configurations

## Navigation

The admin panel features a sidebar with three main sections:

1. **Dashboard** - Main admin dashboard for post creation and management
2. **Users** - User management interface
3. **Image Editor** - Direct access to the image editing tool

## Getting Started

1. Install dependencies:
   ```bash
   npm install
   ```

2. Start the development server:
   ```bash
   npm run dev
   ```

3. Access the admin panel at `http://localhost:5173`

## Authentication

- Admin users can log in with their credentials
- The sidebar includes a logout button for easy session management
- Non-admin users will see the regular user interface

## User Management Features

### Search & Filter
- **Search**: Find users by name, email, or phone number
- **Filter**: View all users, business users only, or personal users only

### User Actions
- **View Details**: Click the eye icon to view detailed user information
- **Delete User**: Click the trash icon to remove a user (with confirmation)

### User Information Displayed
- Profile photo
- Name and email
- Phone number (if available)
- Address and city (if available)
- Account type (Business/Personal)
- Registration date
- Last login information

## Technical Stack

- **Frontend**: React with TypeScript
- **Styling**: Tailwind CSS
- **Icons**: Lucide React
- **Backend**: Firebase (Firestore, Storage, Auth)
- **Build Tool**: Vite

## File Structure

```
src/
├── components/
│   ├── AdminLayout.tsx      # Main admin layout with sidebar
│   ├── AdminDashboard.tsx   # Dashboard component
│   ├── Users.tsx           # User management component
│   ├── ImageEditor.tsx     # Image editing component
│   ├── Sidebar.tsx         # Navigation sidebar
│   └── ...
├── contexts/
│   └── AppContext.tsx      # Application state management
├── types/
│   └── index.ts           # TypeScript type definitions
└── firebase.ts            # Firebase configuration
```

## Development

The admin panel is built with a modular architecture:

- **AdminLayout**: Manages the overall layout and page switching
- **Sidebar**: Handles navigation between different admin sections
- **Individual Components**: Each major feature has its own component

This structure makes it easy to add new admin features in the future. 