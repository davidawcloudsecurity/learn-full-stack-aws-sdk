# learn-full-stack-aws-sdk
How to create a login page that uses IAM cred and retrieve access and secret with expiry timestamp

Let me explain what made it work and the flow:

1. **AWS Authentication Flow**
```javascript
const iamClient = new IAMClient({
    region: 'us-east-1'
});
```
- This creates an IAM client using your configured AWS credentials (from `aws configure`)
- These credentials are NOT the IAM username/password from the form
- These are the access key/secret key of an IAM user with permissions to create access keys

2. **API Endpoint Flow**
```javascript
app.post('/api/get-keys', async (req, res) => {
    const { username } = req.body;
    
    try {
        const command = new CreateAccessKeyCommand({
            UserName: username
        });

        const response = await iamClient.send(command);
        
        res.json({
            accessKey: response.AccessKey.AccessKeyId,
            secretKey: response.AccessKey.SecretAccessKey
        });
    } catch (error) {...}
});
```
When a user submits the form:
1. Frontend sends the username to the backend
2. Backend uses its AWS credentials to call `CreateAccessKey` for that username
3. AWS creates new access keys and returns them
4. Backend sends these new keys back to the frontend

3. **Required IAM Permissions**
The AWS credentials you configured must have this IAM policy:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "iam:CreateAccessKey",
            "Resource": "arn:aws:iam::YOUR_ACCOUNT_ID:user/*"
        }
    ]
}
```

4. **Important Security Notes**:
- Each IAM user can have maximum of 2 active access keys
- The secret key is shown only once when created
- In production, you should add:
  - HTTPS
  - Rate limiting
  - Proper error handling
  - Access key rotation logic
