import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";

export interface UploadToS3Params {
  file: File;
  userEmail: string;
  bucket: string
}

export interface UploadToS3Response {
  success: boolean;
  s3Key: string;
  s3Url: string;
  error?: string;
}

export async function uploadToS3({ file, userEmail, bucket }: UploadToS3Params): Promise<UploadToS3Response> {
  const s3Client = new S3Client({
    region: "us-east-1",
  });

  const s3Url = `https://your-bucket.s3.amazonaws.com/${s3Key}`;

  const s3Key = `${userEmail}/${Date.now()}-${file.name}`;
  
  return {
      success: false,
      s3Key: '',
      s3Url: '',
      error: "fail",
    };
}