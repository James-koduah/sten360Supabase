-- Drop existing policies
DROP POLICY IF EXISTS "Anyone can read profile images" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can upload profile images" ON storage.objects;
DROP POLICY IF EXISTS "Organization owners can delete profile images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload profile images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own profile images" ON storage.objects;

-- Create simplified policies
CREATE POLICY "Anyone can read profiles"
ON storage.objects FOR SELECT
USING (bucket_id = 'profiles');

CREATE POLICY "Organization owners can upload profiles"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profiles');

CREATE POLICY "Organization owners can update profiles"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'profiles');

CREATE POLICY "Organization owners can delete profiles"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'profiles');