import { supabaseAdmin } from '../config/supabase.js';
import { UserProfile, UserRole, UserStatus } from '../types/user.types.js';

export class ProfileRepository {
  static async findById(id: string): Promise<UserProfile | null> {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .select('*')
      .eq('id', id)
      .maybeSingle();

    if (error || !data) return null;
    return data as UserProfile;
  }

  static async update(id: string, updates: Partial<UserProfile>): Promise<UserProfile | null> {
    const { data, error } = await supabaseAdmin
      .from('profiles')
      .update({
        ...updates,
        updated_at: new Date().toISOString(),
      })
      .eq('id', id)
      .select()
      .maybeSingle();

    if (error || !data) return null;
    return data as UserProfile;
  }

  static async updateRole(id: string, role: UserRole): Promise<boolean> {
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({ role, updated_at: new Date().toISOString() })
      .eq('id', id);

    return !error;
  }

  static async updateStatus(id: string, status: UserStatus): Promise<boolean> {
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({ status, updated_at: new Date().toISOString() })
      .eq('id', id);

    return !error;
  }

  static async listUsers(limit = 50, offset = 0): Promise<{ users: UserProfile[]; total: number }> {
    const { data, count, error } = await supabaseAdmin
      .from('profiles')
      .select('*', { count: 'exact' })
      .range(offset, offset + limit - 1)
      .order('created_at', { ascending: false });

    if (error || !data) return { users: [], total: 0 };
    return { users: data as UserProfile[], total: count || 0 };
  }

  static async listWithQuery(query: any): Promise<{ items: UserProfile[]; total: number }> {
    let req = supabaseAdmin.from('profiles').select('*', { count: 'exact' });

    if (query.search) {
      req = req.or(`full_name.ilike.%${query.search}%,email.ilike.%${query.search}%`);
    }

    if (query.filters?.role) {
      req = req.eq('role', query.filters.role);
    }
    if (query.filters?.status) {
      req = req.eq('status', query.filters.status);
    }
    if (query.filters?.university_id) {
      req = req.eq('university_id', query.filters.university_id);
    }

    req = req
      .order(query.sortField, { ascending: query.sortAsc })
      .range(query.offset, query.offset + query.limit - 1);

    const { data, count, error } = await req;
    if (error) throw error;
    return { items: (data || []) as UserProfile[], total: count || 0 };
  }

  static async delete(id: string): Promise<boolean> {
    const { error } = await supabaseAdmin
      .from('profiles')
      .update({ status: 'deleted', updated_at: new Date().toISOString() })
      .eq('id', id);

    return !error;
  }
}
