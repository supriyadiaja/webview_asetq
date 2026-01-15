# Implementation Checklist

## Quick Start (5-10 minutes)

### Step 1: Choose Your Method

- [ ] **JWT Method** - Use if you have or want to install `firebase/php-jwt`
  - More secure, stateless, industry standard
  - File: `api_endpoint_solution.php`

- [ ] **Simple Token Method** - Use if you want minimal dependencies
  - No JWT library needed, simpler to understand
  - File: `api_endpoint_simplified.php`

---

## Implementation Steps

### Step 1: Create Token Storage (if using Simple Token method)

```sql
-- Run this in your database
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

### Step 2: Update Your Login Endpoint

Replace your current login logic with token generation:

**For JWT:**
```php
use Firebase\JWT\JWT;

$secret = getenv('JWT_SECRET') ?: 'your-secret-key';
$payload = [
    'id_user' => $user_id,
    'email' => $user_email,
    'iat' => time(),
    'exp' => time() + (24 * 60 * 60)
];

$access_token = JWT::encode($payload, $secret, 'HS256');
echo json_encode(['success' => true, 'access_token' => $access_token]);
```

**For Simple Token:**
```php
$token = bin2hex(random_bytes(32));
$expiry = date('Y-m-d H:i:s', time() + (24 * 60 * 60));

$stmt = $pdo->prepare('
    INSERT INTO user_sessions (id_user, access_token, token_expiry)
    VALUES (?, ?, ?)
');
$stmt->execute([$user_id, $token, $expiry]);

echo json_encode(['success' => true, 'access_token' => $token]);
```

### Step 3: Replace Your API Endpoint

- [ ] Copy the appropriate solution file (JWT or Simplified)
- [ ] Replace your `api/forum/get-user-communities.php` file
- [ ] Update table names to match your database schema
- [ ] Update column names (if different from examples)

### Step 4: Update Flutter WebView

Make sure your web app sends the token:

```javascript
// In your web app's login success handler
localStorage.setItem('access_token', response.data.access_token);

// For API calls
const headers = {
    'Authorization': 'Bearer ' + localStorage.getItem('access_token'),
    'Content-Type': 'application/json'
};

fetch('/api/forum/get-user-communities.php', {
    method: 'GET',
    headers: headers,
    credentials: 'include'
})
.then(r => r.json())
.then(data => {
    if (data.success) {
        console.log('Communities:', data.data);
    } else {
        console.log('Error:', data.message);
    }
});
```

### Step 5: Test

```bash
# Get a valid token from your login endpoint
TOKEN="your-access-token-here"

# Test the API
curl -H "Authorization: Bearer $TOKEN" \
  https://your-api.com/api/forum/get-user-communities.php
```

---

## Troubleshooting

### Issue: "Please login first"

**Checklist:**
- [ ] Token is being generated on login
- [ ] Token is stored in localStorage
- [ ] Token is being sent in Authorization header
- [ ] Token has not expired
- [ ] Authorization header format is correct: `Bearer <token>`
- [ ] Database queries use correct table/column names

**Debug steps:**
```php
// Add this to your endpoint temporarily
error_log('Headers: ' . print_r(getallheaders(), true));
error_log('Token received: ' . ($_SERVER['HTTP_AUTHORIZATION'] ?? 'NONE'));
error_log('User ID: ' . ($id_user ?? 'NULL'));
```

### Issue: CORS Error

Add this to your endpoint:
```php
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Origin: ' . $_SERVER['HTTP_ORIGIN']);
```

### Issue: Token Decoding Fails (JWT)

- [ ] Install JWT library: `composer require firebase/php-jwt`
- [ ] Check `JWT_SECRET` environment variable is set
- [ ] Verify token was encoded with same secret
- [ ] Check PHP error logs for JWT exceptions

### Issue: Database Connection Fails

- [ ] Check `../config/database.php` exists and is configured
- [ ] Verify PDO connection is working
- [ ] Check database credentials in environment

---

## Files Created

1. **api_endpoint_solution.php** - Full solution with JWT support
2. **api_endpoint_simplified.php** - Simple token-based solution
3. **BEARER_TOKEN_AUTH_GUIDE.md** - Comprehensive guide
4. **API_IMPLEMENTATION_CHECKLIST.md** - This file

---

## Next Steps

1. Choose your authentication method (JWT or Simple Token)
2. Update your login endpoint to generate tokens
3. Create the user_sessions table (if using Simple Token)
4. Replace your API endpoint with the appropriate solution
5. Test with curl or Postman
6. Update Flutter WebView to send the token
7. Test from Flutter app

---

## Security Reminders

- **Use HTTPS** in production
- **Rotate tokens** regularly
- **Keep JWT_SECRET safe** - don't commit to git
- **Validate token expiry** - implement refresh tokens for long sessions
- **Rate limit** API endpoints to prevent abuse
- **Sanitize database queries** - always use prepared statements (already done in solutions)

---

## Support

If something isn't working:
1. Check PHP error logs: `tail -f /var/log/php_errors.log`
2. Check server logs: `tail -f /var/log/apache2/error.log`
3. Use curl to test the API directly
4. Verify token format in browser console
5. Check database for stored tokens/sessions
