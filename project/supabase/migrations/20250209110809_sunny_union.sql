/*
  # Add user deletion function

  1. New Function
    - `delete_user_account`: Deletes a user and all associated data
      - Handles cascading deletion of organization data
      - Cleans up storage files
      - Removes auth user

  2. Security
    - Function can only be called by the user being deleted
    - Requires authentication
*/

-- Create function to handle user deletion
CREATE OR REPLACE FUNCTION delete_user_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_org_id uuid;
BEGIN
  -- Get the current user ID
  v_user_id := auth.uid();
  
  -- Get the organization ID for the user
  SELECT id INTO v_org_id
  FROM organizations
  WHERE owner_id = v_user_id;

  -- Delete organization (this will cascade to all related data)
  DELETE FROM organizations
  WHERE id = v_org_id;

  -- Delete storage objects
  DELETE FROM storage.objects
  WHERE bucket_id = 'profiles'
  AND (storage.foldername(name))[1] = v_org_id::text;

  -- Delete the user from auth.users
  DELETE FROM auth.users
  WHERE id = v_user_id;
END;
$$;