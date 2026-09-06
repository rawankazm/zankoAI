/**
 * Firestore to Supabase PostgreSQL Migration Script
 * Migrates existing users, notes, flashcards, and schedule items.
 */
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

dotenv.config();

const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);

export async function migrateUser(firebaseUser: {
  uid: string;
  email: string;
  name: string;
  role: 'student' | 'teacher' | 'admin';
  isVip: boolean;
  vipStatus: string;
}) {
  console.log(`Migrating user: ${firebaseUser.email} (${firebaseUser.uid})...`);
  const { error } = await supabase.from('users').upsert({
    id: firebaseUser.uid,
    email: firebaseUser.email,
    full_name: firebaseUser.name,
    role: firebaseUser.role || 'student',
    is_vip: firebaseUser.isVip || false,
    vip_status: firebaseUser.vipStatus || 'none',
  });

  if (error) {
    console.error(`Error migrating user ${firebaseUser.uid}:`, error);
  } else {
    console.log(`✅ User ${firebaseUser.email} migrated successfully.`);
  }
}

console.log('Migration script ready.');
