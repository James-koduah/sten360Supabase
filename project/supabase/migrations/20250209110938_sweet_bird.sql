/*
  # Fix user deletion function

  1. Changes
    - Add proper error handling
    - Add proper transaction management
    - Fix auth.users deletion by using auth.users table
    - Add proper checks and validations
*/

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

    -- Delete the user from auth.users using raw SQL
    -- This requires the function to be SECURITY DEFINER
    EXECUTE 'DELETE FROM auth.users WHERE id = $1'
    USING v_user_id;

    -- If we get here, commit the transaction
    RAISE NOTICE 'User account deleted successfully';
  EXCEPTION
    WHEN OTHERS THEN
      -- If any error occurs, rollback
      RAISE EXCEPTION 'Failed to delete account: %', SQLERRM;
  END;
END;
$$;