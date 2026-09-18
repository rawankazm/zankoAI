import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';
import multer, { StorageEngine, FileFilterCallback } from 'multer';

export type StorageCategory = 'pdfs' | 'ocr' | 'exports';

export interface SavedFileRecord {
  fileId: string;
  category: StorageCategory;
  filename: string;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  relativePath: string;
  absolutePath: string;
}

const MIME_MAP: Record<string, string> = {
  '.pdf': 'application/pdf',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.gif': 'image/gif',
  '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  '.zip': 'application/zip',
  '.json': 'application/json',
  '.txt': 'text/plain',
};

export class LocalStorageService {
  private static baseDir: string = process.env.STORAGE_PATH || path.resolve(process.cwd(), 'uploads');

  private static readonly CATEGORY_DIRS: Record<StorageCategory, string> = {
    pdfs: 'pdfs',
    ocr: 'ocr',
    exports: 'exports',
  };

  private static readonly ALLOWED_MIME_TYPES: Record<StorageCategory, string[]> = {
    pdfs: ['application/pdf'],
    ocr: ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/tiff'],
    exports: [
      'application/pdf',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/zip',
      'application/json',
      'text/plain',
    ],
  };

  private static readonly SIZE_LIMITS: Record<StorageCategory, number> = {
    pdfs: 25 * 1024 * 1024,   // 25 MB
    ocr: 10 * 1024 * 1024,    // 10 MB
    exports: 50 * 1024 * 1024, // 50 MB
  };

  /**
   * Initializes storage directories on disk
   */
  public static init(): void {
    const categories: StorageCategory[] = ['pdfs', 'ocr', 'exports'];
    for (const cat of categories) {
      const dirPath = path.join(this.baseDir, this.CATEGORY_DIRS[cat]);
      if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true, mode: 0o775 });
      }
    }
  }

  public static getBaseDir(): string {
    return this.baseDir;
  }

  public static setBaseDir(newDir: string): void {
    this.baseDir = newDir;
    this.init();
  }

  /**
   * Resolves safe target directory for a category
   */
  public static getCategoryDir(category: StorageCategory): string {
    const sub = this.CATEGORY_DIRS[category] || 'exports';
    const resolved = path.join(this.baseDir, sub);
    if (!fs.existsSync(resolved)) {
      fs.mkdirSync(resolved, { recursive: true, mode: 0o775 });
    }
    return resolved;
  }

  /**
   * Multer disk storage engine
   */
  public static createDiskStorage(defaultCategory?: StorageCategory): StorageEngine {
    return multer.diskStorage({
      destination: (req: Request, file: Express.Multer.File, cb) => {
        let category: StorageCategory = defaultCategory || 'exports';
        const reqCategory = (req.body?.category || req.params?.category || req.query?.category) as StorageCategory;
        if (reqCategory && LocalStorageService.CATEGORY_DIRS[reqCategory]) {
          category = reqCategory;
        } else if (file.mimetype === 'application/pdf') {
          category = 'pdfs';
        } else if (file.mimetype.startsWith('image/')) {
          category = 'ocr';
        }
        cb(null, LocalStorageService.getCategoryDir(category));
      },
      filename: (_req: Request, file: Express.Multer.File, cb) => {
        const ext = path.extname(file.originalname).toLowerCase();
        const safeExt = /^\.[a-z0-9]+$/i.test(ext) ? ext : '';
        const uniqueFilename = `${crypto.randomUUID()}${safeExt}`;
        cb(null, uniqueFilename);
      },
    });
  }

  /**
   * MIME and Size Validator Filter
   */
  public static createFileFilter(expectedCategory?: StorageCategory) {
    return (_req: Request, file: Express.Multer.File, cb: FileFilterCallback) => {
      const mime = file.mimetype.toLowerCase();
      let category = expectedCategory;

      if (!category) {
        if (mime === 'application/pdf') category = 'pdfs';
        else if (mime.startsWith('image/')) category = 'ocr';
        else category = 'exports';
      }

      const allowed = LocalStorageService.ALLOWED_MIME_TYPES[category] || [];
      if (!allowed.includes(mime)) {
        return cb(new Error(`Invalid file type '${mime}'. Allowed for ${category}: ${allowed.join(', ')}`));
      }
      cb(null, true);
    };
  }

  /**
   * Configured Multer middleware instances
   */
  public static getUploader(category?: StorageCategory) {
    const limits = {
      fileSize: category ? LocalStorageService.SIZE_LIMITS[category] : 25 * 1024 * 1024,
    };

    return multer({
      storage: LocalStorageService.createDiskStorage(category),
      limits,
      fileFilter: LocalStorageService.createFileFilter(category),
    });
  }

  public static readonly uploadPdf = LocalStorageService.getUploader('pdfs');
  public static readonly uploadImage = LocalStorageService.getUploader('ocr');
  public static readonly uploadExport = LocalStorageService.getUploader('exports');
  public static readonly uploadGeneric = LocalStorageService.getUploader();

  /**
   * Programmatic file write (drop-in replacement for legacy Supabase Storage upload)
   */
  public static async saveFile(
    category: StorageCategory,
    originalFilename: string,
    buffer: Buffer
  ): Promise<SavedFileRecord> {
    this.init();

    const maxLimit = this.SIZE_LIMITS[category] || 25 * 1024 * 1024;
    if (buffer.length > maxLimit) {
      throw new Error(`File exceeds maximum size limit of ${Math.round(maxLimit / (1024 * 1024))}MB`);
    }

    const ext = path.extname(originalFilename).toLowerCase();
    const safeExt = /^\.[a-z0-9]+$/i.test(ext) ? ext : '';
    const fileId = crypto.randomUUID();
    const filename = `${fileId}${safeExt}`;
    const categoryDir = this.getCategoryDir(category);
    const absolutePath = path.join(categoryDir, filename);

    await fs.promises.writeFile(absolutePath, buffer);

    return {
      fileId,
      category,
      filename,
      originalName: originalFilename,
      mimeType: MIME_MAP[safeExt] || 'application/octet-stream',
      sizeBytes: buffer.length,
      relativePath: `${this.CATEGORY_DIRS[category]}/${filename}`,
      absolutePath,
    };
  }

  /**
   * File deletion (drop-in replacement for legacy Supabase Storage remove)
   */
  public static async deleteFile(category: StorageCategory, filename: string): Promise<boolean> {
    const sanitized = path.basename(filename);
    const targetPath = path.join(this.getCategoryDir(category), sanitized);

    try {
      if (fs.existsSync(targetPath)) {
        await fs.promises.unlink(targetPath);
        return true;
      }
    } catch {
      return false;
    }
    return false;
  }

  /**
   * Resolve an existing file path safely without path traversal
   */
  public static resolveFile(fileIdOrPath: string): { filePath: string; mimeType: string } | null {
    // Prevent directory traversal attacks
    if (fileIdOrPath.includes('..') || fileIdOrPath.includes('\0') || fileIdOrPath.includes('\\')) {
      return null;
    }

    const cleanInput = fileIdOrPath.replace(/^\/+/, '');
    const categories: StorageCategory[] = ['pdfs', 'ocr', 'exports'];

    // 1. Direct match if input already contains category prefix (e.g. "pdfs/abc-123.pdf")
    const candidateDirect = path.join(this.baseDir, cleanInput);
    if (fs.existsSync(candidateDirect) && fs.statSync(candidateDirect).isFile()) {
      const ext = path.extname(candidateDirect).toLowerCase();
      return {
        filePath: candidateDirect,
        mimeType: MIME_MAP[ext] || 'application/octet-stream',
      };
    }

    // 2. Search by basename / fileId across categories
    const baseName = path.basename(cleanInput);
    for (const cat of categories) {
      const catDir = path.join(this.baseDir, this.CATEGORY_DIRS[cat]);
      if (!fs.existsSync(catDir)) continue;

      // Exact filename match
      const candidateExact = path.join(catDir, baseName);
      if (fs.existsSync(candidateExact) && fs.statSync(candidateExact).isFile()) {
        const ext = path.extname(candidateExact).toLowerCase();
        return {
          filePath: candidateExact,
          mimeType: MIME_MAP[ext] || 'application/octet-stream',
        };
      }

      // UUID prefix match if extension was omitted
      const files = fs.readdirSync(catDir);
      const matched = files.find((f) => f.startsWith(baseName));
      if (matched) {
        const full = path.join(catDir, matched);
        const ext = path.extname(full).toLowerCase();
        return {
          filePath: full,
          mimeType: MIME_MAP[ext] || 'application/octet-stream',
        };
      }
    }

    return null;
  }

  /**
   * HTTP Stream and Download handler with full HTTP 206 Range Request support
   */
  public static handleDownloadStream(req: Request, res: Response, next?: NextFunction): void {
    try {
      const fileId = req.params.fileId;
      if (!fileId) {
        res.status(400).json({ success: false, error: 'BadRequest', message: 'Missing fileId parameter' });
        return;
      }

      const fileInfo = LocalStorageService.resolveFile(fileId);
      if (!fileInfo) {
        res.status(404).json({ success: false, error: 'NotFound', message: 'Requested file does not exist' });
        return;
      }

      const { filePath, mimeType } = fileInfo;
      const stat = fs.statSync(filePath);
      const fileSize = stat.size;
      const range = req.headers.range;

      res.setHeader('Accept-Ranges', 'bytes');
      res.setHeader('Content-Type', mimeType);

      if (range) {
        // Range: bytes=start-end
        const parts = range.replace(/bytes=/, '').split('-');
        const start = parseInt(parts[0], 10);
        const end = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;

        if (isNaN(start) || start >= fileSize || (parts[1] && end >= fileSize) || start > end) {
          res.status(416).setHeader('Content-Range', `bytes */${fileSize}`).end();
          return;
        }

        const chunkSize = end - start + 1;
        res.status(206);
        res.setHeader('Content-Range', `bytes ${start}-${end}/${fileSize}`);
        res.setHeader('Content-Length', chunkSize);

        const stream = fs.createReadStream(filePath, { start, end });
        stream.on('error', (err) => {
          if (!res.headersSent) res.status(500).json({ error: 'StreamError', message: err.message });
        });
        stream.pipe(res);
      } else {
        res.status(200);
        res.setHeader('Content-Length', fileSize);

        const stream = fs.createReadStream(filePath);
        stream.on('error', (err) => {
          if (!res.headersSent) res.status(500).json({ error: 'StreamError', message: err.message });
        });
        stream.pipe(res);
      }
    } catch (err: any) {
      if (next) next(err);
      else res.status(500).json({ success: false, error: 'InternalError', message: err.message });
    }
  }
}

// Auto-initialize directories on startup
LocalStorageService.init();

export default LocalStorageService;
