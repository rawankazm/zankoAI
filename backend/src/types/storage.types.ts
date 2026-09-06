import { QuotaCheckResult } from './usage.types.js';

export type StorageCategory =
  | 'avatars'
  | 'lecture-files'
  | 'pdfs'
  | 'ocr-images'
  | 'audio'
  | 'homework-images'
  | 'generated-files';

export interface StorageBucketConfig {
  id: StorageCategory;
  isPublic: boolean;
  maxSizeBytes: number;
  allowedExtensions: string[];
  allowedMimeTypes: string[];
  defaultExpiresInSeconds: number; // For signed URLs
}

export interface StorageUploadTicketRequest {
  category: StorageCategory;
  originalFileName: string;
  fileSizeBytes: number;
  mimeType: string;
  courseId?: string;       // Required for lecture-files
  lectureId?: string;      // Optional for lecture-files / audio
  assignmentId?: string;   // Required for homework-images
}

export interface StorageUploadTicketResponse {
  category: StorageCategory;
  bucket: string;
  storagePath: string;
  signedUploadUrl?: string;
  token?: string;
  expiresInSeconds: number;
  maxSizeBytes: number;
  publicUrl?: string; // Only populated for public buckets like avatars
  usage?: QuotaCheckResult;
}

export interface StorageSignedUrlRequest {
  category: StorageCategory;
  storagePath: string;
  expiresInSeconds?: number; // Default 900 (15 min), max 3600 (1 hour)
}

export interface StorageSignedUrlResponse {
  signedUrl: string;
  expiresAt: string;
  expiresInSeconds: number;
  category: StorageCategory;
  storagePath: string;
}

export interface StorageDeleteRequest {
  category: StorageCategory;
  storagePath: string;
}

export interface StorageCleanupReport {
  scannedCount: number;
  deletedCount: number;
  reclaimedBytes: number;
  timestamp: string;
}
