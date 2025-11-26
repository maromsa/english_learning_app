# Gemini 3 Pro Prompt - Step 5: Settings & User Selection Screens Redesign

## Context
You are redesigning a Flutter educational app for children learning English. The app is in Hebrew (RTL) and uses Material 3 design. This step focuses on two related screens: **Settings Screen** and **User Selection Screen**, along with the **Create User Screen**. These screens handle user management, profile settings, and app configuration.

## Current App Theme
The app uses a custom theme (`AppTheme`) with:
- Primary colors: Blue (#4A90E2), Purple (#7B68EE), Green (#50C878), Orange (#FF6B6B), Yellow (#FFD93D)
- Font: Google Fonts Nunito (child-friendly)
- Material 3 design system
- RTL support for Hebrew

## Screens to Redesign

### 1. Settings Screen (`lib/screens/settings_screen.dart`)
The main settings screen where users can:
- View/edit their profile
- Select/edit character
- Toggle dark mode
- Reset progress
- Clear word cache
- Switch users
- Sign out

### 2. User Selection Screen (`lib/screens/user_selection_screen.dart`)
The screen for selecting or creating users:
- Shows Google user card (if authenticated)
- Lists all local users
- Create new user button
- Link users to Google accounts
- Delete users
- Select active user

### 3. Create User Screen (`lib/screens/create_user_screen.dart`)
Form for creating new user profiles:
- Name input
- Age input
- Photo picker
- Google sign-in option
- Create button

## Current Settings Screen Code

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  final themeProvider = context.watch<ThemeProvider>();
  final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

  return Scaffold(
    appBar: AppBar(title: const Text('הגדרות')),
    body: ListView(
      children: [
        _buildProfileHeader(context),
        const Divider(),
        // Character section
        Consumer<CharacterProvider>(
          builder: (context, characterProvider, _) {
            if (characterProvider.hasCharacter) {
              return ListTile(
                leading: CharacterAvatar(character: characterProvider.character!, size: 48),
                title: Text(characterProvider.character!.characterName),
                subtitle: const Text('הדמות שלך'),
                trailing: const Icon(Icons.edit),
                onTap: () => _editCharacter(context),
              );
            } else {
              return ListTile(
                leading: const Icon(Icons.person_add, size: 48),
                title: const Text('בחר דמות'),
                subtitle: const Text('עדיין לא בחרת דמות'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _selectCharacter(context),
              );
            }
          },
        ),
        const Divider(),
        SwitchListTile.adaptive(
          secondary: const Icon(Icons.dark_mode),
          title: const Text('מצב כהה'),
          subtitle: const Text('עברו בין מצב יום ולילה'),
          value: isDarkMode,
          onChanged: (value) async {
            await themeProvider.toggleTheme(value);
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.auto_fix_high),
          title: const Text('איפוס התקדמות במפה'),
          subtitle: const Text('מאפס כוכבים ומטבעות שהושגו בשלבים'),
          enabled: !_isBusy,
          onTap: _isBusy ? null : () => _confirmResetProgress(context),
        ),
        ListTile(
          leading: const Icon(Icons.cleaning_services),
          title: const Text('ניקוי מטמון מילים'),
          subtitle: const Text('מוחק מילים שנשמרו במכשיר לצורך טעינה מהירה'),
          enabled: !_isBusy,
          onTap: _isBusy ? null : () => _clearWordCache(context),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.swap_horiz),
          title: const Text('החלפת משתמש'),
          subtitle: const Text('בחרו משתמש אחר או צרו משתמש חדש'),
          enabled: !_isBusy,
          onTap: _isBusy ? null : () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
            );
            if (mounted) {
              await _loadLocalUser();
              if (result == true) {
                Navigator.of(context).pop();
              }
            }
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('התנתקות מהחשבון'),
          subtitle: const Text('חזרה למסך הכניסה של Google'),
          enabled: !_isBusy,
          onTap: _isBusy ? null : () async {
            setState(() => _isBusy = true);
            try {
              await context.read<AuthProvider>().signOut();
            } finally {
              if (mounted) {
                setState(() => _isBusy = false);
              }
            }
          },
        ),
      ],
    ),
  );
}
```

### Profile Header
```dart
Widget _buildProfileHeader(BuildContext context) {
  final authProvider = context.watch<AuthProvider>();
  final appUser = authProvider.currentUser;
  final firebaseUser = authProvider.firebaseUser;

  final hasLocalUser = _localUserName != null;
  final displayName = _localUserName ?? appUser?.displayName ?? firebaseUser?.displayName ?? 'משתמש ללא שם';
  final subtitle = hasLocalUser
      ? 'גיל: $_localUserAge - משתמש מקומי'
      : (appUser?.email ?? firebaseUser?.email ?? 'לא נמצאה כתובת Gmail');
  final photoUrl = _localUserPhotoUrl ?? appUser?.photoUrl ?? firebaseUser?.photoURL;

  return ListTile(
    leading: CircleAvatar(
      radius: 28,
      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
          : null,
    ),
    title: Text(displayName),
    subtitle: Text(subtitle),
    trailing: authProvider.isBusy
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : null,
    onTap: () async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UserSelectionScreen()),
      );
      if (result == true && mounted) {
        setState(() {});
      }
    },
  );
}
```

## Current User Selection Screen Code

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  final authProvider = context.watch<AuthProvider>();

  return Scaffold(
    appBar: AppBar(
      title: const Text('בחרו משתמש'),
      actions: [
        if (authProvider.isAuthenticated)
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'התנתקות',
            onPressed: () async {
              await authProvider.signOut();
              if (!mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const SignInScreen()),
              );
            },
          ),
      ],
    ),
    body: _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              if (authProvider.isAuthenticated)
                _buildGoogleUserCard(authProvider),
              Expanded(
                child: _users.isEmpty ? _buildEmptyState() : _buildUsersList(),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: FilledButton.icon(
                  onPressed: _createNewUser,
                  icon: const Icon(Icons.person_add),
                  label: const Text('צור משתמש חדש'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
  );
}
```

### Google User Card
```dart
Widget _buildGoogleUserCard(AuthProvider authProvider) {
  final appUser = authProvider.currentUser;
  final firebaseUser = authProvider.firebaseUser;
  final name = appUser?.displayName ?? firebaseUser?.displayName ?? 'משתמש Google';
  final email = appUser?.email ?? firebaseUser?.email ?? '';
  final photoUrl = appUser?.photoUrl ?? firebaseUser?.photoURL;

  return Card(
    margin: const EdgeInsets.all(16),
    child: ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
        child: photoUrl == null
            ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'G', style: const TextStyle(fontSize: 24))
            : null,
      ),
      title: Text(name),
      subtitle: Text(email),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      },
    ),
  );
}
```

### Users List
```dart
Widget _buildUsersList() {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _users.length,
    itemBuilder: (context, index) {
      final user = _users[index];
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null
                ? Text(user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24))
                : null,
          ),
          title: Text(user.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('גיל: ${user.age}'),
              if (user.isLinkedToGoogle)
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 16, color: Colors.green),
                    const SizedBox(width: 4),
                    Text(user.googleEmail ?? 'מחובר ל-Google', style: const TextStyle(fontSize: 12)),
                  ],
                )
              else
                TextButton.icon(
                  onPressed: () => _linkUserToGoogle(user),
                  icon: const Icon(Icons.link, size: 16),
                  label: const Text('קשר ל-Google'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (user.isActive)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check_circle, color: Colors.green),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: Colors.red,
                onPressed: () => _deleteUser(user),
              ),
            ],
          ),
          onTap: () => _selectUser(user),
        ),
      );
    },
  );
}
```

## Current Create User Screen Code

### Main Build Method
```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('יצירת משתמש חדש')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'צרו פרופיל משתמש חדש',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
                child: _selectedImage == null
                    ? const Icon(Icons.camera_alt, size: 50)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _pickImage,
              child: const Text('בחרו תמונה'),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'שם',
                hintText: 'הזינו את השם',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
              textDirection: TextDirection.rtl,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'אנא הזינו שם';
                }
                if (value.trim().length < 2) {
                  return 'השם חייב להכיל לפחות 2 תווים';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'גיל',
                hintText: 'הזינו את הגיל',
                prefixIcon: Icon(Icons.cake),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              textDirection: TextDirection.rtl,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'אנא הזינו גיל';
                }
                final age = int.tryParse(value);
                if (age == null) {
                  return 'אנא הזינו מספר תקין';
                }
                if (age < 3 || age > 18) {
                  return 'הגיל חייב להיות בין 3 ל-18';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _isLinkingGoogle || _isCreating ? null : _linkToGoogle,
              icon: _isLinkingGoogle
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.login),
              label: Text(_googleUid != null
                  ? 'מחובר ל-Google: $_googleEmail'
                  : 'התחבר עם Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_googleUid != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  '✓ חשבון Google מקושר',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isCreating ? null : _createUser,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isCreating
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('צור משתמש'),
            ),
          ],
        ),
      ),
    ),
  );
}
```

## Current Issues

### Settings Screen
1. **Basic List Layout** - Simple ListView with dividers, not very engaging
2. **Profile Header** - Plain ListTile, could be more prominent
3. **No Visual Hierarchy** - All options look the same
4. **Character Section** - Could be more visually appealing
5. **No Grouping** - Settings are not grouped by category
6. **Basic Icons** - Standard Material icons, could be more colorful

### User Selection Screen
1. **Basic Card Layout** - Simple cards, not very exciting
2. **Google User Card** - Looks like a regular card, should stand out
3. **Empty State** - Basic icon and text, could be more inviting
4. **User Cards** - All look the same, active user not clearly highlighted
5. **Delete Button** - Small icon button, could be clearer
6. **No Visual Feedback** - Limited animations or transitions

### Create User Screen
1. **Basic Form** - Standard form layout, not very engaging
2. **Photo Picker** - Simple CircleAvatar, could be more interactive
3. **No Visual Guidance** - Could use illustrations or hints
4. **Google Button** - Standard button, could be more prominent
5. **No Progress Indication** - Form feels static

## Redesign Goals

### Settings Screen
1. **Hero Profile Section**
   - Large, prominent profile card at the top
   - Beautiful avatar with gradient background
   - Clear user information display
   - Quick access to user selection

2. **Grouped Settings**
   - Visual sections with headers
   - Character section with preview
   - App settings grouped together
   - Account actions grouped separately

3. **Visual Enhancements**
   - Colorful icons for each setting
   - Better visual hierarchy
   - Smooth animations
   - Card-based layout

4. **Child-Friendly Design**
   - Large touch targets
   - Clear labels
   - Visual feedback
   - Engaging colors

### User Selection Screen
1. **Hero Google User Card**
   - Prominent card for Google user (if authenticated)
   - Clear visual distinction
   - Easy access to map

2. **Enhanced User Cards**
   - Larger, more colorful cards
   - Clear active user indicator
   - Better avatar display
   - Visual feedback on selection

3. **Empty State**
   - Friendly illustration or icon
   - Encouraging message
   - Clear call-to-action

4. **Create User Button**
   - Large, prominent button
   - Floating action button style (optional)
   - Clear icon and label

5. **Better Organization**
   - Clear sections
   - Smooth animations
   - Visual hierarchy

### Create User Screen
1. **Hero Photo Section**
   - Large, interactive photo picker
   - Clear instructions
   - Visual feedback

2. **Form Design**
   - Better input fields
   - Clear labels and hints
   - Visual validation feedback
   - Progress indication

3. **Google Integration**
   - Prominent Google sign-in button
   - Clear connection status
   - Visual feedback

4. **Submit Button**
   - Large, prominent button
   - Clear loading state
   - Success feedback

## Design Requirements
- **Child-friendly**: Bright, colorful, playful, engaging
- **Accessible**: Large touch targets (min 48x48dp), clear contrast, readable text
- **RTL Support**: All layouts must work correctly in Hebrew
- **Performance**: Smooth 60fps animations, optimized rendering
- **Responsive**: Works on different screen sizes (phones, tablets)
- **Material 3**: Follow Material 3 design guidelines
- **Consistent**: Match the design language of other redesigned screens

## Your Task
Redesign all three screens with:

### Settings Screen
1. **Hero Profile Card**
   - Large card at the top with gradient background
   - Prominent avatar (larger, with border/glow)
   - User name and info clearly displayed
   - Tap to switch users

2. **Character Section**
   - Card-based layout
   - Character preview with avatar
   - Clear edit button
   - Visual feedback

3. **Settings Groups**
   - "הגדרות אפליקציה" (App Settings) section
   - "פעולות חשבון" (Account Actions) section
   - Each with header and grouped items
   - Colorful icons

4. **Visual Polish**
   - Smooth animations
   - Better spacing
   - Card-based items
   - Color-coded sections

### User Selection Screen
1. **Google User Hero Card**
   - Large, prominent card at top
   - Gradient background or special styling
   - Clear "משתמש Google" label
   - Easy tap to continue

2. **User Cards**
   - Larger cards with more padding
   - Active user highlighted (border, glow, badge)
   - Better avatar display
   - Age and Google status clearly shown
   - Smooth selection animation

3. **Empty State**
   - Friendly illustration or large icon
   - Encouraging Hebrew text
   - Clear next steps

4. **Create Button**
   - Large, floating-style button
   - Prominent placement
   - Clear icon and label

5. **Delete Action**
   - Swipe-to-delete (optional) or clear button
   - Confirmation dialog (preserve existing)

### Create User Screen
1. **Photo Picker**
   - Large, interactive circle
   - Clear camera icon
   - Border/glow when selected
   - Instructions text

2. **Form Fields**
   - Better styled inputs
   - Clear labels
   - Visual validation
   - Helper text

3. **Google Button**
   - Prominent button with Google colors
   - Clear connection status
   - Visual feedback

4. **Submit Button**
   - Large, prominent button
   - Loading state
   - Success animation

## Output Format
Provide:
1. Complete refactored code for all three screens
2. Any new helper widgets/components needed
3. Brief explanation of design decisions
4. List of any new dependencies needed (if any)

## Code Style
- Use Material 3 components
- Follow Flutter best practices
- Use const constructors where possible
- Add meaningful comments
- Keep code readable and maintainable
- Preserve all existing functionality

## Important Notes
- **Preserve all functionality**: All existing features must work exactly as before
- **Keep navigation**: All navigation flows must be preserved
- **Maintain state management**: Keep all existing state variables and providers
- **RTL Support**: Ensure all layouts work correctly in Hebrew (RTL)
- **Animations**: Use smooth, child-friendly animations
- **Error Handling**: Preserve all error handling and validation
- **Google Integration**: Maintain all Google sign-in functionality
- **User Management**: Preserve all user creation, selection, deletion, and linking logic

## Current Data Available

### Settings Screen
- `_localUserName`, `_localUserAge`, `_localUserPhotoUrl` - Local user data
- `authProvider.currentUser`, `authProvider.firebaseUser` - Firebase user data
- `characterProvider.character` - Selected character
- `themeProvider.themeMode` - Theme mode

### User Selection Screen
- `_users` - List of LocalUser objects
- `authProvider.isAuthenticated` - Google auth status
- User properties: `name`, `age`, `photoUrl`, `isLinkedToGoogle`, `googleEmail`, `isActive`

### Create User Screen
- `_nameController`, `_ageController` - Form controllers
- `_selectedImage` - Selected photo file
- `_googleUid`, `_googleEmail`, `_googleDisplayName`, `_googlePhotoUrl` - Google data
- `_isCreating`, `_isLinkingGoogle` - Loading states

## Design Inspiration
Think of:
- Modern profile screens in apps
- User selection in games
- Onboarding flows
- Settings screens with clear organization
- Child-friendly interfaces with large touch targets

Please provide the complete redesigned code for all three screens.


