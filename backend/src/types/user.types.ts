export type UserRole = 'student' | 'teacher' | 'admin';
export type UserStatus = 'active' | 'suspended' | 'deleted';
export type SubscriptionPlan = 'free' | 'premium';

export interface UserProfile {
  id: string;
  email: string;
  full_name: string;
  role: UserRole;
  status: UserStatus;
  plan: SubscriptionPlan;
  is_vip: boolean;
  vip_status: string;
  vip_expiry?: string | null;
  score: number;
  rank_title: string;
  university_id?: string | null;
  department_id?: string | null;
  university_name?: string | null;
  department_name?: string | null;
  city_name?: string | null;
  avatar_url?: string | null;
  created_at: string;
  updated_at: string;
}

export interface AuthUserToken {
  id: string;
  email?: string;
  role?: string;
  app_metadata?: Record<string, any>;
  user_metadata?: Record<string, any>;
}
