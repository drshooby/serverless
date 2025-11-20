import os
import json
import uuid
import psycopg2
import boto3

s3 = boto3.client("s3")
secrets_client = boto3.client("secretsmanager")
secret_arn = os.environ["DB_SECRET_ARN"]

def get_db_credentials():
    resp = secrets_client.get_secret_value(SecretId=secret_arn)
    secret = json.loads(resp["SecretString"])
    return secret

creds = get_db_credentials()
BUCKET_NAME = creds["BUCKET_NAME"]

# Create connection - will be reused across invocations
conn = None

def get_connection():
    global conn
    if conn is None or conn.closed:
        conn = psycopg2.connect(
            host=creds["host"],
            port=creds["port"],
            dbname=creds["dbname"],
            user=creds["username"],
            password=creds["password"],
            connect_timeout=5,
            sslmode='require'
        )
    return conn

def build_api_rsp(output, status):
    return {
        "statusCode": status,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "POST"
        },
        "body": json.dumps(output)
    }

def get_presigned(filetype, key):
    match filetype:
        case "video":
            expire_time = 1200
        case "image":
            expire_time = 3600
    
    try:
        presigned = s3.generate_presigned_url(
                "get_object",
                Params={"Bucket": BUCKET_NAME, "Key": key},
                ExpiresIn=expire_time
            )
        return presigned, expire_time
    except Exception as e:
        print(f"ERROR - Failed to generate presigned URL: {str(e)}")
        return None, None


def create_video_record(data):
    user_email = data["userEmail"]
    job_id = data["jobId"]
    output_key = data["outputKey"]
    thumbnail_key = data["thumbnailKey"]
    input_key = data.get("inputKey")
    video_id = str(uuid.uuid4())

    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO videos (id, user_email, job_id, input_key, output_key, thumbnail_key, created_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
        """, (video_id, user_email, job_id, input_key, output_key, thumbnail_key))
        conn.commit()

    # step function use, no api call
    return {
        "status": "ok",
        "videoId": video_id,
        "message": "Video record created."
    }


def list_videos(data):
    user_email = data["userEmail"]
    
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, job_id, output_key, thumbnail_key, created_at
            FROM videos
            WHERE user_email = %s
            ORDER BY created_at DESC
        """, (user_email,))
        rows = cur.fetchall()

    results = []
    for r in rows:
        video_id, job_id, output_key, thumbnail_key, created_at = r
        
        thumbnail_result = get_presigned("image", thumbnail_key)
        thumbnail_url = thumbnail_result[0] if thumbnail_result else None

        results.append({
            "videoId": video_id,
            "jobId": job_id,
            "outputKey": output_key,
            "thumbnailUrl": thumbnail_url if thumbnail_url else "",
            "createdAt": created_at.isoformat()
        })

    return build_api_rsp(results, 200)


def get_video_url(data):    
    video_id = data["videoId"]
    
    conn = get_connection()
    
    with conn.cursor() as cur:
        cur.execute("""
            SELECT output_key FROM videos WHERE id = %s
        """, (video_id,))
        row = cur.fetchone()
    
    print(f"DEBUG - Query result: {row}")

    if not row:
        print("ERROR - Video not found in database")
        return build_api_rsp({"error": "Video not found"}, 404)

    output_key = row[0]

    presigned, expire_time = get_presigned("video", output_key)

    if presigned:
        result = {
            "videoId": video_id,
            "url": presigned,
            "expiresIn": expire_time
        }
        status = 200
    else:
        result = {
            "error": "Failed to generate presigned URL"
        }
        status = 500
    
    return build_api_rsp(result, status)

def delete_video(data):
    video_id = data["videoId"]
    
    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("SELECT output_key, thumbnail_key FROM videos WHERE id = %s", (video_id,))
        row = cur.fetchone()

    if not row:
        return {"error": "Video not found"}

    output_key, thumbnail_key = row

    with conn.cursor() as cur:
        cur.execute("DELETE FROM videos WHERE id = %s", (video_id,))
        conn.commit()

    s3.delete_object(Bucket=BUCKET_NAME, Key=output_key)
    if thumbnail_key:
        s3.delete_object(Bucket=BUCKET_NAME, Key=thumbnail_key)

    return {
        "status": "ok",
        "message": "Video deleted.",
        "videoId": video_id
    }


def lambda_handler(event, context):    
    # Step Functions passes data directly, API Gateway wraps it in 'body'
    if "body" in event:
        # API Gateway call
        try:
            body = json.loads(event["body"]) if isinstance(event["body"], str) else event["body"]
        except Exception:
            body = {}
    else:
        # Direct invocation (Step Functions)
        body = event
    
    operation = body.get("operation")

    conn = get_connection()
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS videos (
                id UUID PRIMARY KEY,
                user_email TEXT NOT NULL,
                job_id TEXT NOT NULL,
                input_key TEXT,
                output_key TEXT NOT NULL,
                thumbnail_key TEXT NOT NULL,
                created_at TIMESTAMP DEFAULT NOW()
            );
            CREATE INDEX IF NOT EXISTS idx_videos_user_email ON videos(user_email);
        """)
        conn.commit()

    match operation:
        case "createVideoRecord":
            result = create_video_record(body)
            # Step Function call - return plain dict
            return result
        case "listVideos":
            return list_videos(body)
        case "getVideoURL":
            return get_video_url(body)
        case "deleteVideo":
            return delete_video(body)
        case _:
            return build_api_rsp({"error": "Invalid operation"}, 400)