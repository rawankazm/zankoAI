-- ==============================================================================
-- ZankoAI Migration: Secure Supabase Storage System
-- Migration: 20260906000005_secure_storage_system.sql
-- ==============================================================================

-- 1. Create or Update Storage Buckets with strict size and MIME constraints
-- Only 'avatars' is public (for public profile pictures).
-- All other 6 buckets are strictly private (public = false).

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  (
    'avatars',
    'avatars',
    true,
    2097152, -- 2 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'lecture-files',
    'lecture-files',
    false,
    52428800, -- 50 MB
    ARRAY[
      'application/pdf',
      'application/vnd.ms-powerpoint',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain'
    ]
  ),
  (
    'pdfs',
    'pdfs',
    false,
    31457280, -- 30 MB
    ARRAY['application/pdf']
  ),
  (
    'ocr-images',
    'ocr-images',
    false,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'audio',
    'audio',
    false,
    26214400, -- 25 MB
    ARRAY[
      'audio/mpeg',
      'audio/mp4',
      'audio/wav',
      'audio/x-wav',
      'audio/aac',
      'audio/ogg',
      'audio/webm',
      'audio/x-m4a'
    ]
  ),
  (
    'homework-images',
    'homework-images',
    false,
    10485760, -- 10 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'application/pdf']
  ),
  (
    'generated-files',
    'generated-files',
    false,
    20971520, -- 20 MB
    ARRAY['application/pdf', 'audio/mpeg', 'application/json', 'text/plain']
  )
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

-- 2. Enable Row-Level Security on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ─── Helper Functions for Storage RLS ───
CREATE OR REPLACE FUNCTION public.is_admin_or_service()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    auth.role() = 'service_role' OR
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_course_instructor(p_course_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.courses
    WHERE id = p_course_id AND instructor_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_course_member(p_course_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN (
    public.is_course_instructor(p_course_id) OR
    EXISTS (
      SELECT 1 FROM public.enrollments
      WHERE course_id = p_course_id AND student_id = auth.uid()
    ) OR
    EXISTS (
      SELECT 1 FROM public.courses c
      JOIN public.profiles p ON p.id = auth.uid()
      WHERE c.id = p_course_id AND c.department_id = p.department_id
    )
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ─── 3. RLS Policies: avatars (Public Read, Owner Write) ───
DROP POLICY IF EXISTS "Avatars are viewable by everyone" ON storage.objects;
CREATE POLICY "Avatars are viewable by everyone"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "Users can upload their own avatar" ON storage.objects;
CREATE POLICY "Users can upload their own avatar"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'avatars' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

DROP POLICY IF EXISTS "Users can update their own avatar" ON storage.objects;
CREATE POLICY "Users can update their own avatar"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'avatars' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

DROP POLICY IF EXISTS "Users can delete their own avatar" ON storage.objects;
CREATE POLICY "Users can delete their own avatar"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'avatars' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

-- ─── 4. RLS Policies: lecture-files (Course Scoped) ───
-- Path format: {course_id}/{lecture_id}/{filename}
DROP POLICY IF EXISTS "Course members can view lecture files" ON storage.objects;
CREATE POLICY "Course members can view lecture files"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'lecture-files' AND
  (
    public.is_admin_or_service() OR
    public.is_course_member((storage.foldername(name))[1]::uuid)
  )
);

DROP POLICY IF EXISTS "Instructors can upload lecture files" ON storage.objects;
CREATE POLICY "Instructors can upload lecture files"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'lecture-files' AND
  (
    public.is_admin_or_service() OR
    public.is_course_instructor((storage.foldername(name))[1]::uuid)
  )
);

DROP POLICY IF EXISTS "Instructors can delete lecture files" ON storage.objects;
CREATE POLICY "Instructors can delete lecture files"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'lecture-files' AND
  (
    public.is_admin_or_service() OR
    public.is_course_instructor((storage.foldername(name))[1]::uuid)
  )
);

-- ─── 5. RLS Policies: pdfs, ocr-images, generated-files (User Private) ───
-- Path format: {user_id}/{filename}
DROP POLICY IF EXISTS "Users can access their own private PDFs" ON storage.objects;
CREATE POLICY "Users can access their own private PDFs"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'pdfs' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

DROP POLICY IF EXISTS "Users can upload their own private PDFs" ON storage.objects;
CREATE POLICY "Users can upload their own private PDFs"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'pdfs' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

DROP POLICY IF EXISTS "Users can delete their own private PDFs" ON storage.objects;
CREATE POLICY "Users can delete their own private PDFs"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'pdfs' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

-- OCR Images:
DROP POLICY IF EXISTS "Users can access their own OCR scans" ON storage.objects;
CREATE POLICY "Users can access their own OCR scans"
ON storage.objects FOR ALL
USING (
  bucket_id = 'ocr-images' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
)
WITH CHECK (
  bucket_id = 'ocr-images' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

-- Generated Files:
DROP POLICY IF EXISTS "Users can access their own generated files" ON storage.objects;
CREATE POLICY "Users can access their own generated files"
ON storage.objects FOR ALL
USING (
  bucket_id = 'generated-files' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
)
WITH CHECK (
  bucket_id = 'generated-files' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

-- Audio files:
DROP POLICY IF EXISTS "Users can access their own audio recordings" ON storage.objects;
CREATE POLICY "Users can access their own audio recordings"
ON storage.objects FOR ALL
USING (
  bucket_id = 'audio' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
)
WITH CHECK (
  bucket_id = 'audio' AND
  (auth.uid() IS NOT NULL AND (storage.foldername(name))[1] = auth.uid()::text OR public.is_admin_or_service())
);

-- ─── 6. RLS Policies: homework-images ───
-- Path format: {assignment_id}/{student_id}/{filename}
DROP POLICY IF EXISTS "Authorized users can view homework submissions" ON storage.objects;
CREATE POLICY "Authorized users can view homework submissions"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'homework-images' AND
  (
    public.is_admin_or_service() OR
    -- Student owner
    (storage.foldername(name))[2] = auth.uid()::text OR
    -- Course instructor for this assignment
    EXISTS (
      SELECT 1 FROM public.assignments a
      JOIN public.courses c ON c.id = a.course_id
      WHERE a.id = (storage.foldername(name))[1]::uuid AND c.instructor_id = auth.uid()
    )
  )
);

DROP POLICY IF EXISTS "Students can upload homework submissions" ON storage.objects;
CREATE POLICY "Students can upload homework submissions"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'homework-images' AND
  (
    public.is_admin_or_service() OR
    (auth.uid() IS NOT NULL AND (storage.foldername(name))[2] = auth.uid()::text)
  )
);

DROP POLICY IF EXISTS "Students can delete their own homework submissions" ON storage.objects;
CREATE POLICY "Students can delete their own homework submissions"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'homework-images' AND
  (
    public.is_admin_or_service() OR
    (auth.uid() IS NOT NULL AND (storage.foldername(name))[2] = auth.uid()::text)
  )
);

-- ─── 7. Orphaned Files Cleanup Routine ───
CREATE OR REPLACE FUNCTION public.get_orphaned_storage_files(p_older_than_hours INT DEFAULT 24)
RETURNS TABLE (
  bucket_id TEXT,
  file_name TEXT,
  created_at TIMESTAMPTZ
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    o.bucket_id::text,
    o.name::text,
    o.created_at
  FROM storage.objects o
  WHERE o.created_at < (NOW() - (p_older_than_hours || ' hours')::interval)
    AND (
      -- Avatars not in profiles
      (o.bucket_id = 'avatars' AND NOT EXISTS (
        SELECT 1 FROM public.profiles p WHERE p.avatar_url LIKE '%' || o.name || '%'
      ))
      OR
      -- Lecture files not in lectures
      (o.bucket_id = 'lecture-files' AND NOT EXISTS (
        SELECT 1 FROM public.lectures l WHERE l.file_url LIKE '%' || o.name || '%'
      ))
      OR
      -- Homework not in submissions
      (o.bucket_id = 'homework-images' AND NOT EXISTS (
        SELECT 1 FROM public.assignment_submissions s WHERE s.file_url LIKE '%' || o.name || '%'
      ))
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
