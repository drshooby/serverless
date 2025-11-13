export interface UploadToS3Params {
  file: File;
  userEmail: string;
  gatewayURI: string;
}

export interface UploadToS3Response {
  success: boolean;
  s3Key: string;
  s3Url: string;
  error?: string;
}

export async function uploadToS3({ file, userEmail, gatewayURI }: UploadToS3Params): Promise<UploadToS3Response> {
  try {
    const response = await fetch(`${gatewayURI}/get-upload-url`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        userEmail: userEmail,
        fileName: file.name,
        contentType: file.type
      })
    });

    const { presignedUrl, s3Key, s3Url } = await response.json();

    await fetch(presignedUrl, {
      method: 'PUT',
      body: file,
      headers: {
        'Content-Type': file.type
      }
    });

    return {
      success: true,
      s3Key: s3Key,
      s3Url: s3Url,
      error: undefined
    };
  } catch (error) {
    console.error("Upload error:", error);
    return {
      success: false,
      s3Key: '',
      s3Url: '',
      error: error instanceof Error ? error.message : "Upload failed"
    };
  }
}