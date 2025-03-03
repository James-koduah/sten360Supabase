-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can read profiles" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can upload profiles" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can update profiles" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can delete profiles" ON storage.objects;

-- Create new, more permissive policies
CREATE POLICY "Public profiles access"
ON storage.objects FOR SELECT
USING (bucket_id = 'profiles');

CREATE POLICY "Authenticated users can upload profiles"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profiles');

CREATE POLICY "Authenticated users can update profiles"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'profiles');

CREATE POLICY "Authenticated users can delete profiles"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'profiles');