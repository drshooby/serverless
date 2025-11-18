export interface UploadToS3Params {
  file: File;
  userEmail: string;
}

export interface UploadToS3Response {
  success: boolean;
  s3Key: string;
  s3Url: string;
  error?: string;
}

interface PollResult {
  jobId: string;
  status: 'RUNNING' | 'SUCCEEDED' | 'FAILED' | 'TIMED_OUT' | 'ABORTED' | 'PENDING_REDRIVE';
  isComplete: boolean;
  startDate: string;
  stopDate?: string;
  output?: string;
  error?: string;
  cause?: string;
  found?: boolean;
  message?: string;
}

export class MontageClient {
  constructor(private readonly gatewayURI: string) {}

  async getPastMontages(userEmail: string) {
    const payload = {
      operation: "listVideos",
      userEmail
    };

    const response = await fetch(`${this.gatewayURI}/videos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    return await response.json();
  }

  async getMontage(montageId: string) {
    // Implementation here
  }

  private async pollJobStatus(jobID: string): Promise<PollResult> {
    const response = await fetch(`${this.gatewayURI}/poll`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ jobId: jobID })
    });

    if (!response.ok) {
      throw new Error(`Polling failed: ${response.status}`);
    }

    return await response.json();
  }

  async uploadToS3({ file, userEmail }: UploadToS3Params): Promise<UploadToS3Response> {
    try {
      const response = await fetch(`${this.gatewayURI}/get-upload-url`, {
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

      const { presignedUrl, s3Key, s3Url, jobID } = await response.json();

      await fetch(presignedUrl, {
        method: 'PUT',
        body: file,
        headers: {
          'Content-Type': file.type
        }
      });

      console.log("Sent to S3.");

      let status = await this.pollJobStatus(jobID);

      while (!status.isComplete) {
        await new Promise(resolve => setTimeout(resolve, 10000));
        status = await this.pollJobStatus(jobID);
        console.log(`Current status: ${status.status}`);
      }

      if (status.status === 'SUCCEEDED') {
        console.log('Job succeeded!', status.output);
      } else if (status.status === 'FAILED') {
        console.error('Job failed:', status.error, status.cause);
      }

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
}