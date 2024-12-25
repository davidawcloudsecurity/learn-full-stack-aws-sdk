const express = require('express');
const { 
    IAMClient, 
    CreateAccessKeyCommand,
    TagUserCommand 
} = require('@aws-sdk/client-iam');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const port = 3000;

app.use(bodyParser.json());
app.use(express.static(path.join(__dirname, 'public')));

const iamClient = new IAMClient({
    region: 'us-east-1'
});

async function tagUserWithExpiry(username, accessKeyId, expiryDate) {
    const command = new TagUserCommand({
        UserName: username,
        Tags: [
            {
                Key: `ExpiryDate-${accessKeyId}`,
                Value: expiryDate.toISOString()
            }
        ]
    });

    await iamClient.send(command);
}

app.post('/api/get-keys', async (req, res) => {
    const { username, expiryDays } = req.body;
    
    try {
        // Calculate expiry date
        const expiryDate = new Date();
        expiryDate.setDate(expiryDate.getDate() + parseInt(expiryDays));

        // Create new access key
        const command = new CreateAccessKeyCommand({
            UserName: username
        });

        const response = await iamClient.send(command);
        
        // Tag the user with expiry information
        await tagUserWithExpiry(
            username, 
            response.AccessKey.AccessKeyId, 
            expiryDate
        );

        res.json({
            accessKey: response.AccessKey.AccessKeyId,
            secretKey: response.AccessKey.SecretAccessKey,
            expiryDate: expiryDate.toISOString()
        });

    } catch (error) {
        console.error('Error:', error);
        res.status(400).json({
            message: 'Failed to create access key: ' + error.message
        });
    }
});

app.listen(port, () => {
    console.log(`Server running at http://localhost:${port}`);
});
