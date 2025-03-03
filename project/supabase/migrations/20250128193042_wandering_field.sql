-- Drop existing policies
DROP POLICY IF EXISTS "Public profiles access" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profiles" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update profiles" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete profiles" ON storage.objects;

-- Create the profiles bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('profiles', 'profiles', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Create new storage policies
CREATE POLICY "Allow public read access"
ON storage.objects FOR SELECT
USING (bucket_id = 'profiles');

CREATE POLICY "Allow authenticated users to upload files"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profiles');

CREATE POLICY "Allow authenticated users to update their files"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'profiles');

CREATE POLICY "Allow authenticated users to delete their files"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'profiles');