/*
  # Storage Setup

  1. Create Storage Bucket
    - Creates a new bucket called 'profiles' for storing worker profile images
  
  2. Security
    - Enables RLS on the bucket
    - Adds policies for authenticated users to:
      - Upload files
      - Read files
      - Delete their own files
*/

-- Create the profiles bucket if it doesn't exist
INSERT INTO storage.buckets (id, name)
VALUES ('profiles', 'profiles')
ON CONFLICT (id) DO NOTHING;

-- Set up RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Policy for reading files (anyone can read)
CREATE POLICY "Anyone can read profile images"
ON storage.objects FOR SELECT
USING (bucket_id = 'profiles');

-- Policy for uploading files (authenticated users only)
CREATE POLICY "Authenticated users can upload profile images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy for deleting files (users can only delete their own)
CREATE POLICY "Users can delete their own profile images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profiles' AND
  (storage.foldername(name))[1] = auth.uid()::text
);