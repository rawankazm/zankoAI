export type ReportStatus = 'draft' | 'processing' | 'completed' | 'failed' | 'archived';
export type SeminarStatus = 'draft' | 'processing' | 'completed' | 'failed' | 'archived';

export interface ReportSection {
  id: string;
  report_id: string;
  section_order: number;
  title: string;
  content: string;
  bullet_points: string[];
  page_number: number;
  key_takeaway?: string;
  created_at: string;
  updated_at: string;
}

export interface AcademicReport {
  id: string;
  user_id: string;
  title: string;
  subject?: string;
  topic?: string;
  language: string;
  description?: string;
  content?: string;
  student_name?: string;
  supervisor_name?: string;
  university_name?: string;
  department_name?: string;
  academic_year?: string;
  writing_style: string;
  length_level: string;
  logo_url?: string;
  status: ReportStatus;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
  sections?: ReportSection[];
}

export interface CreateReportDTO {
  title: string;
  subject?: string;
  topic?: string;
  language?: string;
  description?: string;
  content?: string;
  student_name?: string;
  supervisor_name?: string;
  university_name?: string;
  department_name?: string;
  academic_year?: string;
  writing_style?: string;
  length_level?: string;
  logo_url?: string;
  status?: ReportStatus;
  metadata?: Record<string, any>;
  sections?: Array<{
    section_order: number;
    title: string;
    content: string;
    bullet_points?: string[];
    page_number?: number;
    key_takeaway?: string;
  }>;
}

export interface UpdateReportDTO {
  title?: string;
  subject?: string;
  topic?: string;
  language?: string;
  description?: string;
  content?: string;
  student_name?: string;
  supervisor_name?: string;
  university_name?: string;
  department_name?: string;
  academic_year?: string;
  writing_style?: string;
  length_level?: string;
  logo_url?: string;
  status?: ReportStatus;
  metadata?: Record<string, any>;
  sections?: Array<{
    id?: string;
    section_order: number;
    title: string;
    content: string;
    bullet_points?: string[];
    page_number?: number;
    key_takeaway?: string;
  }>;
}

export interface SeminarSection {
  id: string;
  seminar_id: string;
  section_order: number;
  title: string;
  content?: string;
  bullet_points: string[];
  speaker_notes?: string;
  visual_prompt?: string;
  image_url?: string;
  category_tag?: string;
  created_at: string;
  updated_at: string;
}

export interface Seminar {
  id: string;
  user_id: string;
  title: string;
  subject?: string;
  topic?: string;
  language: string;
  description?: string;
  content?: string;
  status: SeminarStatus;
  metadata: Record<string, any>;
  created_at: string;
  updated_at: string;
  slides?: SeminarSection[];
}

export interface CreateSeminarDTO {
  title: string;
  subject?: string;
  topic?: string;
  language?: string;
  description?: string;
  content?: string;
  status?: SeminarStatus;
  metadata?: Record<string, any>;
  slides?: Array<{
    section_order: number;
    title: string;
    content?: string;
    bullet_points?: string[];
    speaker_notes?: string;
    visual_prompt?: string;
    image_url?: string;
    category_tag?: string;
  }>;
}

export interface UpdateSeminarDTO {
  title?: string;
  subject?: string;
  topic?: string;
  language?: string;
  description?: string;
  content?: string;
  status?: SeminarStatus;
  metadata?: Record<string, any>;
  slides?: Array<{
    id?: string;
    section_order: number;
    title: string;
    content?: string;
    bullet_points?: string[];
    speaker_notes?: string;
    visual_prompt?: string;
    image_url?: string;
    category_tag?: string;
  }>;
}

export interface AcademicQueryOptions {
  page?: number;
  limit?: number;
  search?: string;
  status?: string;
  language?: string;
}
