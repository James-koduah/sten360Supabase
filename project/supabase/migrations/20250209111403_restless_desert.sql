/*
  # Fix user deletion permissions

  1. Changes
    - Grant proper permissions to delete_user_account function
    - Add proper role to execute auth.users deletion
*/

-- First revoke any existing grants
REVOKE EXECUTE ON FUNCTION delete_user_account FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION delete_user_account FROM authenticated;
REVOKE EXECUTE ON FUNCTION delete_user_account FROM anon;

-- Grant execute to authenticated users only
GRANT EXECUTE ON FUNCTION delete_user_account TO authenticated;

-- Grant proper role for auth schema
GRANT USAGE ON SCHEMA auth TO postgres;
GRANT ALL ON auth.users TO postgres;

-- Recreate the function with proper permissions
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
  
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Start transaction
  BEGIN
    -- Get the organization ID for the user
    SELECT id INTO v_org_id
    FROM organizations
    WHERE owner_id = v_user_id;

    IF v_org_id IS NULL THEN
      RAISE EXCEPTION 'Organization not found';
    END IF;

    -- Delete organization (this will cascade to all related data)
    DELETE FROM organizations
    WHERE id = v_org_id;

    -- Delete storage objects
    DELETE FROM storage.objects
    WHERE bucket_id = 'profiles'
    AND (storage.foldername(name))[1] = v_org_id::text;

    -- Delete the user from auth.users
    -- Using elevated privileges from SECURITY DEFINER
    DELETE FROM auth.users WHERE id = v_user_id;

    -- If we get here, commit the transaction
    RAISE NOTICE 'User account deleted successfully';
  EXCEPTION
    WHEN OTHERS THEN
      -- If any error occurs, rollback and re-raise
      RAISE EXCEPTION 'Failed to delete account: %', SQLERRM;
  END;
END;
$$;