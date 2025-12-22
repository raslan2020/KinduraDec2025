# Asynchronous JSON Processing API

This implementation allows you to upload JSON files and process them asynchronously in the background, so the frontend doesn't have to wait for the processing to complete.

## API Endpoints

### 1. Upload JSON File
**POST** `/api/users/upload_json/`

Upload a JSON file and start background processing.

**Request:**
- Content-Type: `multipart/form-data`
- Authentication: Required (Bearer token)
- Body: Form data with `file` field containing JSON file

**Response:**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "status": "pending",
    "uploaded_at": "2024-01-15T10:30:00Z",
    "message": "JSON uploaded successfully. Processing started in background."
  },
  "message": "JSON uploaded successfully"
}
```

### 2. Check Processing Status
**GET** `/api/users/{upload_id}/json_status/`

Check the current status of a JSON upload processing.

**Response (Pending/Processing):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "status": "processing",
    "uploaded_at": "2024-01-15T10:30:00Z"
  }
}
```

**Response (Completed):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "status": "completed",
    "uploaded_at": "2024-01-15T10:30:00Z",
    "summarize_patient_report": {
      "processed_at": 1705312200.123,
      "data_size": 1024,
      "fields_count": 5,
      "processing_summary": {
        "status": "success",
        "message": "JSON file processed successfully"
      }
    }
  }
}
```

**Response (Failed):**
```json
{
  "success": true,
  "data": {
    "id": 1,
    "status": "failed",
    "uploaded_at": "2024-01-15T10:30:00Z",
    "error_message": "Invalid JSON format"
  }
}
```

### 3. List All JSON Uploads
**GET** `/api/users/json_uploads/`

Get all JSON uploads for the authenticated user.

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "id": 1,
      "status": "completed",
      "uploaded_at": "2024-01-15T10:30:00Z",
      "summarize_patient_report": { ... }
    },
    {
      "id": 2,
      "status": "processing",
      "uploaded_at": "2024-01-15T10:35:00Z"
    }
  ]
}
```

## Frontend Implementation Example

Here's how you can implement this in your frontend:

```javascript
// 1. Upload JSON file
async function uploadJSON(file) {
  const formData = new FormData();
  formData.append('file', file);
  
  const response = await fetch('/api/users/upload_json/', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`
    },
    body: formData
  });
  
  const result = await response.json();
  return result.data;
}

// 2. Poll for status updates
async function checkStatus(uploadId) {
  const response = await fetch(`/api/users/${uploadId}/json_status/`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });
  
  return await response.json();
}

// 3. Monitor processing
async function monitorProcessing(uploadId) {
  const pollInterval = setInterval(async () => {
    const result = await checkStatus(uploadId);
    const status = result.data.status;
    
    if (status === 'completed') {
      clearInterval(pollInterval);
      console.log('Processing completed:', result.data.summarize_patient_report);
      // Handle completion
    } else if (status === 'failed') {
      clearInterval(pollInterval);
      console.error('Processing failed:', result.data.error_message);
      // Handle error
    }
    // Continue polling if status is 'pending' or 'processing'
  }, 2000); // Poll every 2 seconds
}

// Usage example
async function handleFileUpload(file) {
  try {
    // Upload file and get immediate response
    const uploadResult = await uploadJSON(file);
    console.log('File uploaded, processing started');
    
    // Start monitoring the processing
    monitorProcessing(uploadResult.id);
    
  } catch (error) {
    console.error('Upload failed:', error);
  }
}
```

## Processing Status Values

- **`pending`**: File uploaded, processing not yet started
- **`processing`**: Background processing is currently running
- **`completed`**: Processing finished successfully
- **`failed`**: Processing failed with an error

## Customizing the Processing Logic

To customize what happens during JSON processing, edit the `process_json_file_async` function in `users/tasks.py`. Currently it includes:

- Simulated processing time (5 seconds)
- Basic data analysis (size, field count)
- Custom processing logic can be added here

## Benefits

1. **Immediate Response**: Frontend gets instant feedback that upload was successful
2. **Non-blocking**: User can continue using the app while processing happens
3. **Status Tracking**: Real-time updates on processing progress
4. **Error Handling**: Proper error reporting if processing fails
5. **Scalable**: Can handle multiple uploads simultaneously 