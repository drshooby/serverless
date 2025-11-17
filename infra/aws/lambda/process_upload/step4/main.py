import boto3
import json
import subprocess
import os

s3 = boto3.client('s3')
bedrock = boto3.client('bedrock-runtime', region_name='us-east-1')
polly = boto3.client('polly')

def lambda_handler(event, context):
    video_key = event['videoKey']
    email = event['email']
    clips = event['clips']
    bucket = event['bucket']
    
    # Download video from S3
    video_file = '/tmp/video.mp4'
    print(f"Downloading video from s3://{bucket}/{video_key}...")
    s3.download_file(bucket, video_key, video_file)

    if not clips:
        print("No clips to process")
        return {
            'videoKey': video_key,
            'email': email,
            'clips': [],
            'totalClips': 0
        }

    # Download background music from S3
    music_key = 'music/mortals.mp3'
    music_file = '/tmp/background_music.mp3'
    print(f"Downloading background music from s3://{bucket}/{music_key}...")

    try:
        s3.download_file(bucket, music_key, music_file)
        print(f"Music downloaded to {music_file}")
    except Exception as e:
        print(f"Error downloading music: {e}")
        music_file = None

    output_clips = []

    prompt = "Generate ONE short sentence of hype commentary for a Valorant game highlight. Maximum 12 words. Just the commentary sentence, nothing else."

    for i, clip in enumerate(clips):
        # Step 1: Generate commentary with Bedrock
        print("  Generating commentary with Bedrock...")

        try:
            response = bedrock.invoke_model(
                modelId='amazon.titan-text-express-v1',
                body=json.dumps({
                    "inputText": prompt,
                    "textGenerationConfig": {
                        "maxTokenCount": 100,
                        "temperature": 0.7
                    }
                })
            )

            response_body = json.loads(response['body'].read())
            commentary = response_body['results'][0]['outputText'].strip()
            # Clean up any markdown or quotes
            commentary = commentary.split('\n')[-1].strip('"\'')
            print(f"  Commentary: {commentary}")
        except Exception as e:
            print(f"  Bedrock error: {e}")
            commentary = "Nice play!"

        # Step 2: Generate audio with Polly
        print("  Generating audio with Polly...")
        audio_file = f'/tmp/commentary_{i}.mp3'

        try:
            polly_response = polly.synthesize_speech(
                Text=commentary,
                OutputFormat='mp3',
                VoiceId='Stephen',
                Engine='generative'
            )

            with open(audio_file, 'wb') as f:
                f.write(polly_response['AudioStream'].read())
            print(f"  Audio saved to {audio_file}")
        except Exception as e:
            print(f"  Polly error: {e}")
            continue

        # Step 3: Extract video clip
        print("  Extracting video clip...")
        clip_file = f'/tmp/clip_{i}.mp4'

        try:
            subprocess.run([
                'ffmpeg', '-i', video_file,
                '-ss', str(clip['start']),
                '-to', str(clip['end']),
                '-c', 'copy',
                '-y', clip_file
            ], check=True, capture_output=True)
            print(f"  Clip extracted to {clip_file}")
        except subprocess.CalledProcessError as e:
            print(f"  ffmpeg extract error: {e.stderr.decode()}")
            continue

        # Step 4: Overlay audio and music on clip
        print("  Overlaying audio and music...")
        final_file = f'/tmp/final_{i}.mp4'

        try:
            if music_file and os.path.exists(music_file):
                # Mix commentary + background music
                subprocess.run([
                    'ffmpeg', '-i', clip_file,
                    '-i', audio_file,
                    '-i', music_file,
                    '-filter_complex', '[2:a]volume=0.2[bg];[1:a][bg]amix=inputs=2:duration=shortest[a]',
                    '-map', '0:v:0',
                    '-map', '[a]',
                    '-c:v', 'copy',
                    '-shortest',
                    '-y', final_file
                ], check=True, capture_output=True)
                print(f"  Final clip with music created: {final_file}")
            else:
                # Just overlay commentary (no music)
                subprocess.run([
                    'ffmpeg', '-i', clip_file,
                    '-i', audio_file,
                    '-c:v', 'copy',
                    '-map', '0:v:0',
                    '-map', '1:a:0',
                    '-shortest',
                    '-y', final_file
                ], check=True, capture_output=True)
                print(f"  Final clip created: {final_file}")
        except subprocess.CalledProcessError as e:
            print(f"  ffmpeg overlay error: {e.stderr.decode()}")
            continue

        # Step 5: Upload to S3 in output directory
        video_filename = video_key.split('/')[-1]
        output_key = f"{email}/output/{video_filename}_clip_{i}.mp4"

        try:
            s3.upload_file(final_file, bucket, output_key)
            print(f"  Uploaded to s3://{bucket}/{output_key}")

            output_clips.append({
                'clipNumber': i + 1,
                'start': clip['start'],
                'end': clip['end'],
                'commentary': commentary,
                's3Key': output_key
            })
        except Exception as e:
            print(f"  S3 upload error: {e}")

        # Cleanup temp files
        for temp_file in [audio_file, clip_file, final_file]:
            if os.path.exists(temp_file):
                os.unlink(temp_file)

    # Cleanup video file
    if video_file and os.path.exists(video_file):
        os.unlink(video_file)
        print(f"\nCleaned up video file: {video_file}")

    # Cleanup music file
    if music_file and os.path.exists(music_file):
        os.unlink(music_file)

    return {
        'videoKey': video_key,
        'email': email,
        'clips': output_clips,
        'totalClips': len(output_clips)
    }