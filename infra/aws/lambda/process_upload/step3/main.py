BUFFER_SECONDS = 3.0

def lambda_handler(event, context):
    video_key = event['videoKey']
    email = event['email']
    bucket = event['bucket']
    kill_timestamps = event['killTimestamps']
    
    print(f"Merging {len(kill_timestamps)} kill timestamps")
    
    if not kill_timestamps:
        print("No kills detected")
        return {
            'videoKey': video_key,
            'email': email,
            'bucket': bucket,
            'clips': [],
            'totalClips': 0
        }
    
    # Merge intervals with buffer
    clips = merge_intervals(kill_timestamps, BUFFER_SECONDS)
    print(f"Merged into {len(clips)} clips")
    
    return {
        'videoKey': video_key,
        'email': email,
        'bucket': bucket,
        'clips': clips,
        'totalClips': len(clips)
    }

def merge_intervals(timestamps, buffer):
    if not timestamps:
        return []
    
    timestamps.sort(key=lambda x: x['time'])
    
    intervals = []
    for ts in timestamps:
        start = max(0, ts['time'] - buffer)
        end = ts['time'] + buffer
        intervals.append({'start': start, 'end': end})
    
    merged = [intervals[0]]
    
    for current in intervals[1:]:
        last = merged[-1]
        
        if current['start'] <= last['end']:
            last['end'] = max(last['end'], current['end'])
        else:
            merged.append(current)
    
    for interval in merged:
        interval['start'] = round(interval['start'], 1)
        interval['end'] = round(interval['end'], 1)
    
    return merged