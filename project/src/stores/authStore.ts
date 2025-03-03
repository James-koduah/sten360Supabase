import { create } from 'zustand';
import { User } from '@supabase/supabase-js';
import { supabase, killAllSessions } from '../lib/supabase';

interface Organization {
  id: string;
  name: string;
  owner_id: string;
  country?: string;
  city?: string;
  address?: string;
  employee_count?: number;
  currency: string;
  subscription_tier?: string;
  subscription_status?: string;
  created_at?: string;
  updated_at?: string;
}

interface AuthState {
  user: User | null;
  organization: Organization | null;
  error: string | null;
  initialized: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, organizationName: string) => Promise<void>;
  signOut: () => Promise<void>;
  deleteAccount: () => Promise<void>;
  killAllSessions: () => Promise<void>;
  refreshSession: () => Promise<void>;
}

export const useAuthStore = create<AuthState>((set) => ({
  user: null,
  organization: null,
  error: null,
  initialized: false,

  refreshSession: async () => {
    try {
      const { data: { session }, error } = await supabase.auth.getSession();

      if (error) throw error;

      if (session?.user) {
        // Load basic organization data
        const { data: orgData, error: orgError } = await supabase
          .from('organizations')
          .select()
          .eq('owner_id', session.user.id)
          .maybeSingle();

        if (orgError) throw orgError;

        set({ 
          user: session.user,
          organization: orgData,
          error: null,
          initialized: true
        });
      } else {
        set({ 
          user: null,
          organization: null,
          error: null,
          initialized: true
        });
      }
    } catch (error) {
      console.error('Error refreshing session:', error);
      await killAllSessions();
      set({ 
        user: null,
        organization: null,
        error: error instanceof Error ? error.message : 'Session expired. Please sign in again.',
        initialized: true
      });
    }
  },

  signIn: async (email: string, password: string) => {
    set({ error: null });
    try {
      // First ensure we're signed out
      await killAllSessions();

      // Attempt to sign in
      const { data: authData, error: authError } = await supabase.auth.signInWithPassword({
        email: email.trim().toLowerCase(),
        password,
      });

      if (authError) {
        if (authError.message === 'Invalid login credentials') {
          throw new Error('Invalid email or password');
        }
        throw authError;
      }

      if (!authData.user) throw new Error('No user returned from sign in');

      // Load organization data
      const { data: orgData, error: orgError } = await supabase
        .from('organizations')
        .select()
        .eq('owner_id', authData.user.id)
        .maybeSingle();

      if (orgError) throw orgError;

      set({ 
        user: authData.user, 
        organization: orgData,
        error: null,
        initialized: true
      });
    } catch (error) {
      console.error('Sign in error:', error);
      set({ 
        user: null, 
        organization: null, 
        error: error instanceof Error ? error.message : 'Failed to sign in',
        initialized: true
      });
      throw error;
    }
  },

  signUp: async (email: string, password: string, organizationName: string) => {
    set({ error: null });
    try {
      // First ensure we're signed out
      await killAllSessions();

      // Attempt to sign up
      const { data: authData, error: authError } = await supabase.auth.signUp({
        email: email.trim().toLowerCase(),
        password,
      });

      if (authError) throw authError;
      if (!authData.user) throw new Error('No user returned from sign up');

      // Create organization
      const { data: orgData, error: orgError } = await supabase
        .from('organizations')
        .insert([{
          name: organizationName.trim(),
          owner_id: authData.user.id
        }])
        .select()
        .single();

      if (orgError) throw orgError;

      set({ 
        user: authData.user,
        organization: orgData,
        error: null,
        initialized: true
      });
    } catch (error) {
      console.error('Sign up error:', error);
      set({ 
        user: null, 
        organization: null, 
        error: error instanceof Error ? error.message : 'Failed to sign up',
        initialized: true
      });
      throw error;
    }
  },

  deleteAccount: async () => {
    try {
      const { error: deleteError } = await supabase
        .rpc('delete_user_account');

      if (deleteError) throw deleteError;

      // Clear local state
      await killAllSessions();
      set({
        user: null,
        organization: null,
        error: null,
        initialized: true
      });
    } catch (error) {
      console.error('Delete account error:', error);
      set({ 
        error: error instanceof Error ? error.message : 'Failed to delete account',
        initialized: true
      });
      throw error;
    }
  },

  signOut: async () => {
    try {
      // First try to sign out normally
      const { error } = await supabase.auth.signOut();
      
      // Even if there's an error, clear local state
      set({
        user: null,
        organization: null,
        error: null,
        initialized: true
      });

      // If normal sign out failed, force kill all sessions
      if (error) {
        await killAllSessions();
      }
    } catch (error) {
      console.error('Sign out error:', error);
      set({ 
        error: error instanceof Error ? error.message : 'Failed to sign out',
        initialized: true
      });
      throw error;
    }
  },

  killAllSessions
}));

// Initialize auth state
const initAuth = async () => {
  try {
    await useAuthStore.getState().refreshSession();
  } catch (error) {
    console.error('Auth initialization error:', error);
  }
};

// Start initialization immediately
initAuth();

// Listen for auth changes
supabase.auth.onAuthStateChange(async (event, session) => {
  if (event === 'SIGNED_OUT') {
    useAuthStore.setState({
      user: null,
      organization: null,
      error: null,
      initialized: true
    });
    return;
  }

  if (event === 'SIGNED_IN' && session?.user) {
    try {
      const { data: orgData, error: orgError } = await supabase
        .from('organizations')
        .select()
        .eq('owner_id', session.user.id)
        .maybeSingle();

      if (orgError) throw orgError;

      useAuthStore.setState({
        user: session.user,
        organization: orgData,
        error: null,
        initialized: true
      });
    } catch (error) {
      console.error('Error loading organization:', error);
      useAuthStore.setState({
        user: session.user,
        organization: null,
        error: error instanceof Error ? error.message : 'Failed to load organization',
        initialized: true
      });
    }
  }
});

// Set up auto-refresh of session
setInterval(async () => {
  const state = useAuthStore.getState();
  if (state.user) {
    await state.refreshSession();
  }
}, 10 * 60 * 1000); // Refresh every 10 minutes

export default useAuthStore;