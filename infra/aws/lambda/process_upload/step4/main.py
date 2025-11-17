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

    output_clips = []
    clip_files = []  # Keep track of processed clips for concatenation

    prompt = "Generate a short sentence of hype commentary for a Valorant game highlight -- keep it generic. " \
    "Make the commentary long enough to span over a 4 second clip." \
    "ONLY output the commentary sentence(s), nothing else."

    for i, clip in enumerate(clips):
        print(f"\nProcessing clip {i + 1}/{len(clips)}: {clip['start']}s - {clip['end']}s")
        
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

        # Step 4: Overlay JUST the commentary audio (no music yet)
        print("  Overlaying commentary audio...")
        final_file = f'/tmp/final_{i}.mp4'

        try:
            subprocess.run([
                'ffmpeg', '-i', clip_file,
                '-i', audio_file,
                '-c:v', 'copy',
                '-map', '0:v:0',
                '-map', '1:a:0',
                '-shortest',
                '-y', final_file
            ], check=True, capture_output=True)
            print(f"  Clip with commentary created: {final_file}")
            
            clip_files.append(final_file)
            
            output_clips.append({
                'clipNumber': i + 1,
                'start': clip['start'],
                'end': clip['end'],
                'commentary': commentary
            })
        except subprocess.CalledProcessError as e:
            print(f"  ffmpeg overlay error: {e.stderr.decode()}")
            continue

        # Cleanup intermediate files (keep final_file for concatenation)
        for temp_file in [audio_file, clip_file]:
            if os.path.exists(temp_file):
                os.unlink(temp_file)

    # Step 5: Concatenate all clips with transitions (if multiple clips)
    video_filename = video_key.split('/')[-1]
    
    if len(clip_files) > 1:
        print(f"\nConcatenating {len(clip_files)} clips with xfade transitions...")
        
        concatenated_file = '/tmp/concatenated.mp4'
        
        try:
            # Build ffmpeg inputs
            inputs = []
            for clip_path in clip_files:
                inputs.extend(['-i', clip_path])
            
            # Get duration of each clip for xfade offsets
            def get_duration(file_path):
                result = subprocess.run([
                    'ffprobe', '-v', 'error',
                    '-show_entries', 'format=duration',
                    '-of', 'default=noprint_wrappers=1:nokey=1',
                    file_path
                ], capture_output=True, text=True)
                return float(result.stdout.strip())
            
            durations = [get_duration(clip) for clip in clip_files]
            
            # Build xfade filter_complex
            transition_duration = 0.5  # 0.5 second crossfade
            
            if len(clip_files) == 2:
                # Simple case: 2 clips
                offset = durations[0] - transition_duration
                filter_complex = f'[0:v][1:v]xfade=transition=fade:duration={transition_duration}:offset={offset}[outv]'
                audio_filter = '[0:a][1:a]acrossfade=d=0.5[outa]'
                
                subprocess.run([
                    'ffmpeg',
                    *inputs,
                    '-filter_complex', f'{filter_complex};{audio_filter}',
                    '-map', '[outv]',
                    '-map', '[outa]',
                    '-c:v', 'mpeg4',
                    '-c:a', 'aac',
                    '-y', concatenated_file
                ], check=True, capture_output=True)
                
            else:
                # 3+ clips: chain xfades
                video_filters = []
                current_offset = 0
                
                for i in range(len(clip_files) - 1):
                    if i == 0:
                        # First transition
                        offset = durations[0] - transition_duration
                        video_filters.append(f'[0:v][1:v]xfade=transition=fade:duration={transition_duration}:offset={offset}[v01]')
                        current_offset = durations[0] + durations[1] - transition_duration
                    else:
                        # Subsequent transitions
                        prev_label = f'v0{i}' if i == 1 else f'v{i-1}{i}'
                        offset = current_offset - transition_duration
                        video_filters.append(f'[{prev_label}][{i+1}:v]xfade=transition=fade:duration={transition_duration}:offset={offset}[v{i}{i+1}]')
                        current_offset += durations[i+1] - transition_duration
                
                final_video_label = f'v{len(clip_files)-2}{len(clip_files)-1}'
                filter_complex = ';'.join(video_filters)
                
                # For now, just use first clip's audio (mixing multiple audio tracks is complex)
                subprocess.run([
                    'ffmpeg',
                    *inputs,
                    '-filter_complex', filter_complex,
                    '-map', f'[{final_video_label}]',
                    '-map', '0:a',  # Use first clip's audio
                    '-c:v', 'mpeg4',
                    '-c:a', 'aac',
                    '-y', concatenated_file
                ], check=True, capture_output=True)
            
            print(f"  Clips concatenated with xfade to {concatenated_file}")
            
        except subprocess.CalledProcessError as e:
            print(f"  xfade error: {e.stderr.decode()}")
            print("  Falling back to simple concat...")
            
            # Fallback to simple concat without transitions
            concat_file = '/tmp/concat_list.txt'
            with open(concat_file, 'w') as f:
                for clip_path in clip_files:
                    f.write(f"file '{clip_path}'\n")
            
            subprocess.run([
                'ffmpeg',
                '-f', 'concat',
                '-safe', '0',
                '-i', concat_file,
                '-c', 'copy',
                '-y', concatenated_file
            ], check=True, capture_output=True)
        
    else:
        concatenated_file = clip_files[0] if clip_files else None

    # Step 6: Add background music to the final concatenated video
    music_file = None
    if concatenated_file:
        print("\nAdding background music to final video...")
        
        # Download background music
        music_key = 'music/mortals.mp3'
        music_file = '/tmp/background_music.mp3'
        
        try:
            s3.download_file(bucket, music_key, music_file)
            print(f"  Music downloaded to {music_file}")
            
            final_output = '/tmp/final_with_music.mp4'
            
            # Mix existing audio with background music
            subprocess.run([
                'ffmpeg',
                '-i', concatenated_file,
                '-i', music_file,
                '-filter_complex', '[1:a]volume=0.2[bg];[0:a][bg]amix=inputs=2:duration=first[a]',
                '-map', '0:v',
                '-map', '[a]',
                '-c:v', 'copy',
                '-shortest',
                '-y', final_output
            ], check=True, capture_output=True)
            
            print(f"  Final video with music created: {final_output}")
            
        except Exception as e:
            print(f"  Music overlay error: {e}")
            final_output = concatenated_file  # Use version without music
    else:
        final_output = None

    # Step 7: Upload final video to S3
    if final_output:
        output_key = f"{email}/output/{video_filename}_montage.mp4"
        
        try:
            s3.upload_file(final_output, bucket, output_key)
            print(f"  Uploaded final video to s3://{bucket}/{output_key}")
            
            # Update output_clips with the final montage key
            for clip in output_clips:
                clip['montageKey'] = output_key
                
        except Exception as e:
            print(f"  S3 upload error: {e}")

    # Cleanup all temp files
    cleanup_files = [video_file, music_file, concatenated_file, final_output] + clip_files
    for temp_file in cleanup_files:
        if temp_file and os.path.exists(temp_file):
            try:
                os.unlink(temp_file)
            except:
                pass

    return {
        'videoKey': video_key,
        'email': email,
        'clips': output_clips,
        'totalClips': len(output_clips),
        'montageKey': output_key if final_output else None
    }