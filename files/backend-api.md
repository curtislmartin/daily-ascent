# Backend API Specification

Lightweight Supabase backend for anonymous sensor data collection. No user accounts, no authentication beyond the contributor UUID.

---

## Supabase Project Setup

### Storage Bucket

```sql
-- Create a public bucket for sensor data files
-- Files are write-only from clients, read-only for the ML training pipeline
INSERT INTO storage.buckets (id, name, public) VALUES ('sensor-data', 'sensor-data', false);
```

Bucket structure:
```
sensor-data/
├── push_ups/
│   ├── {contributor_id}_{timestamp}.bin.gz
│   └── ...
├── squats/
│   └── ...
├── sit_ups/
│   └── ...
├── pull_ups/
│   └── ...
├── glute_bridges/
│   └── ...
└── dead_bugs/
    └── ...
```

### Database Tables

```sql
-- Metadata for each uploaded sensor recording
CREATE TABLE sensor_recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contributor_id UUID NOT NULL,
    exercise_id TEXT NOT NULL,
    level INTEGER NOT NULL,
    day_number INTEGER NOT NULL,
    set_number INTEGER NOT NULL,
    confirmed_reps INTEGER NOT NULL,
    counting_mode TEXT NOT NULL,
    device TEXT NOT NULL,  -- 'iphone' or 'apple_watch'
    sample_rate_hz INTEGER NOT NULL DEFAULT 100,
    duration_seconds DOUBLE PRECISION NOT NULL,
    file_path TEXT NOT NULL,  -- path within the storage bucket
    file_size_bytes INTEGER NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Optional demographics (denormalised from contributor)
    age_range TEXT,
    height_range TEXT,
    biological_sex TEXT,
    activity_level TEXT
);

-- Index for querying by exercise (ML training pipeline)
CREATE INDEX idx_recordings_exercise ON sensor_recordings(exercise_id);

-- Index for deletion by contributor
CREATE INDEX idx_recordings_contributor ON sensor_recordings(contributor_id);

-- Index for training pipeline queries (exercise + rep count range)
CREATE INDEX idx_recordings_training ON sensor_recordings(exercise_id, confirmed_reps);
```

### Row Level Security

```sql
-- Enable RLS
ALTER TABLE sensor_recordings ENABLE ROW LEVEL SECURITY;

-- Allow anonymous inserts (no auth required)
CREATE POLICY "Allow anonymous insert" ON sensor_recordings
    FOR INSERT
    WITH CHECK (true);

-- Allow deletion by contributor_id (passed as a header or parameter)
CREATE POLICY "Allow delete by contributor" ON sensor_recordings
    FOR DELETE
    USING (contributor_id = current_setting('request.headers')::json->>'x-contributor-id');

-- No SELECT for clients — only the ML pipeline (service role) reads data
-- Service role bypasses RLS
```

### Storage Policies

```sql
-- Allow anonymous uploads to the sensor-data bucket
CREATE POLICY "Allow anonymous upload" ON storage.objects
    FOR INSERT
    WITH CHECK (bucket_id = 'sensor-data');

-- Allow deletion by contributor (for data deletion requests)
CREATE POLICY "Allow contributor delete" ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'sensor-data'
        AND (storage.foldername(name))[2] LIKE current_setting('request.headers')::json->>'x-contributor-id' || '%'
    );
```

---

## API Endpoints

All endpoints use Supabase's auto-generated REST API. No custom Edge Functions needed for v1.

### Upload Sensor Recording

**Two-step process: upload file to Storage, then insert metadata row.**

**Step 1: Upload compressed sensor data file**

```
POST https://{project}.supabase.co/storage/v1/object/sensor-data/{exercise_id}/{filename}
Headers:
    apikey: {supabase_anon_key}
    Content-Type: application/octet-stream
Body: <gzipped binary sensor data>
```

Filename format: `{contributor_id}_{timestamp}.bin.gz`

**Step 2: Insert metadata**

```
POST https://{project}.supabase.co/rest/v1/sensor_recordings
Headers:
    apikey: {supabase_anon_key}
    Content-Type: application/json
    Prefer: return=minimal
Body:
{
    "contributor_id": "uuid-v4",
    "exercise_id": "push_ups",
    "level": 2,
    "day_number": 8,
    "set_number": 3,
    "confirmed_reps": 22,
    "counting_mode": "post_set_confirmation",
    "device": "apple_watch",
    "sample_rate_hz": 100,
    "duration_seconds": 45.2,
    "file_path": "push_ups/abc123_1713168221.bin.gz",
    "file_size_bytes": 48230,
    "recorded_at": "2026-04-15T08:23:41Z",
    "age_range": "30_39",
    "height_range": "medium",
    "biological_sex": "male",
    "activity_level": "intermediate"
}
```

### Delete Contributor Data

**Deletes all recordings and files for a contributor UUID.**

```
DELETE https://{project}.supabase.co/rest/v1/sensor_recordings?contributor_id=eq.{uuid}
Headers:
    apikey: {supabase_anon_key}
    x-contributor-id: {uuid}
```

Storage files must be deleted separately. The app can list and delete them, or a Supabase Edge Function can handle cascading deletion (v2 improvement).

---

## iOS Client Integration

```swift
// DataUploadService.swift — upload method

func uploadRecording(_ recording: SensorRecording) async throws {
    let supabaseURL = "https://{project}.supabase.co"
    let anonKey = "{supabase_anon_key}"  // from bundled config, NOT hardcoded
    
    // Read and compress the sensor data file
    let fileURL = URL.documentsDirectory.appending(path: recording.filePath)
    let rawData = try Data(contentsOf: fileURL)
    let compressed = try rawData.gzipped()  // use a gzip library or zlib
    
    let fileName = "\(recording.contributorId)_\(recording.recordedAt.timeIntervalSince1970).bin.gz"
    let storagePath = "\(recording.exerciseId)/\(fileName)"
    
    // Step 1: Upload file
    var uploadRequest = URLRequest(url: URL(string: "\(supabaseURL)/storage/v1/object/sensor-data/\(storagePath)")!)
    uploadRequest.httpMethod = "POST"
    uploadRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
    uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
    uploadRequest.httpBody = compressed
    
    let (_, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
    guard (uploadResponse as? HTTPURLResponse)?.statusCode == 200 else {
        throw UploadError.fileUploadFailed
    }
    
    // Step 2: Insert metadata
    let metadata = SensorRecordingUpload(
        contributorId: recording.contributorId,
        exerciseId: recording.exerciseId,
        level: recording.level,
        dayNumber: recording.dayNumber,
        setNumber: recording.setNumber,
        confirmedReps: recording.confirmedReps,
        // ... etc
        filePath: storagePath,
        fileSizeBytes: compressed.count
    )
    
    var metadataRequest = URLRequest(url: URL(string: "\(supabaseURL)/rest/v1/sensor_recordings")!)
    metadataRequest.httpMethod = "POST"
    metadataRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
    metadataRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
    metadataRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
    metadataRequest.httpBody = try JSONEncoder().encode(metadata)
    
    let (_, metadataResponse) = try await URLSession.shared.data(for: metadataRequest)
    guard (metadataResponse as? HTTPURLResponse)?.statusCode == 201 else {
        throw UploadError.metadataInsertFailed
    }
}
```

### Configuration

Store the Supabase URL and anon key in a bundled configuration file (not hardcoded, not in source control). Use a `.xcconfig` file or a `Secrets.plist` added to `.gitignore`.

### Rate Limiting

Supabase applies default rate limits on the anon key. For additional protection:
- Client-side: max 1 upload per second, batch uploads with delays
- Server-side: Supabase's built-in rate limiting on the anon key is sufficient for v1
- Monitor via Supabase dashboard for abuse patterns

---

## ML Training Pipeline (Future — Not Built in v1)

The training pipeline is a separate process that reads from Supabase and trains Create ML models. Outlined here for schema context.

```
1. Query sensor_recordings for exercise_id = "push_ups" with confirmed_reps > 0
2. Download corresponding .bin.gz files from Storage
3. Decompress and parse binary sensor data
4. Segment into individual reps using the confirmed_reps count as label
5. Train Create ML Activity Classifier
6. Export .mlmodel, package into app update
```

Minimum viable dataset: ~500 sets per exercise from ~50 contributors before training is worthwhile.
