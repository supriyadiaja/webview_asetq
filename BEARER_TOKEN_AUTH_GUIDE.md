# PHP API Authentication Solution - Setup Guide

## Overview

This solution enables your Flutter WebView app to authenticate with PHP APIs using Bearer tokens when PHP sessions are not available in the WebView context.

## Two Authentication Methods

### Method 1: JWT Token (Recommended)

**Best for:** Modern applications with stateless authentication

#### Setup Steps:

1. **Install JWT library:**
   ```bash
   composer require firebase/php-jwt
   ```

2. **Generate JWT tokens on login** (in your login endpoint):
   ```php
   use Firebase\JWT\JWT;
   
   // On successful login
   $secret = getenv('JWT_SECRET') ?: 'your-secret-key';
   $payload = [
       'id_user' => $user_id,
       'email' => $user_email,
       'iat' => time(),
       'exp' => time() + (24 * 60 * 60) // 24 hours
   ];
   
   $access_token = JWT::encode($payload, $secret, 'HS256');
   
   // Return to Flutter app
   echo json_encode(['access_token' => $access_token]);
   ```

3. **Store in Flutter (localStorage):**
   - The token is automatically stored by your web app in localStorage
   - WebView will send it in subsequent requests

4. **Set environment variable:**
   ```bash
   JWT_SECRET=your-secure-secret-key
   ```

---

### Method 2: Session Token (Fallback)

**Best for:** Simpler implementations or existing session systems

#### Database Schema:
```sql
CREATE TABLE user_sessions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    id_user INT NOT NULL,
    access_token VARCHAR(255) UNIQUE NOT NULL,
    token_expiry DATETIME NOT NULL,
    last_activity DATETIME DEFAULT CURRENT_TIMESTAMP,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_user) REFERENCES users(id) ON DELETE CASCADE,
    INDEX idx_token (access_token),
    INDEX idx_expiry (token_expiry)
);
```

#### Generate Session Token on Login:
```php
// On successful login
$token = bin2hex(random_bytes(32)); // Generate secure token
$expiry = date('Y-m-d H:i:s', time() + (24 * 60 * 60)); // 24 hours

$stmt = $pdo->prepare('
    INSERT INTO user_sessions (id_user, access_token, token_expiry)
    VALUES (?, ?, ?)
');

$stmt->execute([$user_id, $token, $expiry]);

echo json_encode(['access_token' => $token]);
```

---

## Flutter WebView Configuration

### Make sure your Flutter app sends the token:

```dart
// In your WebView JavaScript bridge
localStorage.setItem('access_token', token);

// Send with every API request
fetch('https://your-api.com/api/forum/get-user-communities.php', {
    method: 'GET',
    credentials: 'include', // For cookies/sessions
    headers: {
        'Authorization': 'Bearer ' + localStorage.getItem('access_token'),
        'Content-Type': 'application/json'
    }
})
.then(response => response.json())
.then(data => console.log(data))
.catch(error => console.error('Error:', error));
```

---

## Testing the Endpoint

### 1. Test with Session (Traditional Web User):
```bash
# Start a session and test
curl -c cookies.txt \
  -b cookies.txt \
  https://your-api.com/api/forum/get-user-communities.php
```

### 2. Test with Bearer Token:
```bash
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  https://your-api.com/api/forum/get-user-communities.php
```

### 3. Test with both:
```bash
curl -c cookies.txt \
  -b cookies.txt \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  https://your-api.com/api/forum/get-user-communities.php
```

---

## Important Configuration

### .env File:
```
JWT_SECRET=your-super-secret-key-change-this
TOKEN_EXPIRY=86400
DB_HOST=localhost
DB_USER=root
DB_PASS=password
DB_NAME=your_database
```

### CORS Configuration:
The endpoint includes basic CORS headers. For production, make them stricter:

```php
// Replace:
header('Access-Control-Allow-Origin: *');

// With:
header('Access-Control-Allow-Origin: https://your-domain.com');
```

---

## Security Best Practices

1. **Use HTTPS** - Always use HTTPS in production
2. **Secure Token Storage** - Tokens should not be exposed in URLs
3. **Token Rotation** - Implement token refresh mechanism
4. **Validate Origins** - Validate CORS origins strictly
5. **Rate Limiting** - Add rate limiting to prevent brute force
6. **Token Expiry** - Keep tokens short-lived (15-30 min, with refresh tokens)

---

## Troubleshooting

### "Please login first" Still Appearing?

1. **Verify Bearer token is being sent:**
   ```javascript
   // In browser console on WebView
   console.log(localStorage.getItem('access_token'));
   ```

2. **Check if token is in Authorization header:**
   - Add this to PHP for debugging:
   ```php
   error_log('Headers: ' . print_r(getallheaders(), true));
   error_log('User ID: ' . ($id_user ?? 'NULL'));
   ```

3. **Verify token format:**
   - Token must start with "Bearer " in the Authorization header
   - Format: `Authorization: Bearer eyJhbGc...`

4. **Check token expiry:**
   - JWT tokens expire after the time specified in 'exp' claim
   - Session tokens expire based on the database `token_expiry` column

### CORS Issues?

Add to your API endpoint headers:
```php
header('Access-Control-Allow-Credentials: true');
```

---

## Database Adjustments

Modify table names and column names in the PHP code to match your schema:

- `users` table → Your actual users table name
- `id_user` → Your user ID column name
- `communities` table → Your communities table name
- `community_members` → Your membership table
- `user_sessions` → Session storage table (if using Method 2)

---

## Additional Notes

- The endpoint first checks sessions (for traditional web users)
- Then falls back to Bearer tokens (for WebView users)
- Both methods can work simultaneously
- Use the provided SQL schema if you choose Method 2
- Adjust query logic to match your actual database structure
