-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Anyone can read profile images" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can upload profile images" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can delete profile images" ON storage.objects;

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

-- Policy for uploading files (organization owners only)
CREATE POLICY "Organization owners can upload profile images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'profiles' AND
  EXISTS (
    SELECT 1 FROM organizations
    WHERE id = (storage.foldername(name))[1]::uuid
    AND owner_id = auth.uid()
  )
);

-- Policy for deleting files (organization owners only)
CREATE POLICY "Organization owners can delete profile images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'profiles' AND
  EXISTS (
    SELECT 1 FROM organizations
    WHERE id = (storage.foldername(name))[1]::uuid
    AND owner_id = auth.uid()
  )
);