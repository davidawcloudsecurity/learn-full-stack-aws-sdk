// app.js
const express = require('express');
const { IAMClient, CreateAccessKeyCommand } = require('@aws-sdk/client-iam');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const port = 3000;

// Middleware
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

// Move your index.html to public folder
// Add this before your route handlers
const { STSClient, GetCallerIdentityCommand } = require("@aws-sdk/client-sts");

// Test AWS connectivity
const stsClient = new STSClient({ region: 'us-east-1' });

async function testAWSConnection() {
    try {
        const command = new GetCallerIdentityCommand({});
        const response = await stsClient.send(command);
        console.log("AWS Connection Successful. Account ID:", response.Account);
        return true;
    } catch (error) {
        console.error("AWS Connection Failed:", error);
        return false;
    }
}

// Call this when your app starts
testAWSConnection();


app.post('/api/get-keys', async (req, res) => {
    const { username, password } = req.body;

    try {
        // Create IAM client with user credentials
        const iamClient = new IAMClient({
            region: 'us-east-1', // Change to your region
            credentials: {
                accessKeyId: username,     // Note: This isn't correct way to use username/password
                secretAccessKey: password  // This is just for demonstration
            }
        });

        try {
            // Attempt to create new access key
            const command = new CreateAccessKeyCommand({
                UserName: username
            });

            const response = await iamClient.send(command);

            res.json({
                accessKey: response.AccessKey.AccessKeyId,
                secretKey: response.AccessKey.SecretAccessKey
            });

        } catch (error) {
            console.error('Error creating access key:', error);
            res.status(400).json({
                message: 'Failed to create access key. Check your credentials.'
            });
        }

    } catch (error) {
        console.error('Error:', error);
        res.status(500).json({
            message: 'Internal server error'
        });
    }
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
