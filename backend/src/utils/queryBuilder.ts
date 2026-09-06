import { Request } from 'express';
import { PaginatedResult } from '../types/common.types.js';

export interface QueryOptions {
  allowedSortFields: string[];
  defaultSortField?: string;
  defaultSortAsc?: boolean;
  defaultLimit?: number;
  maxLimit?: number;
  searchColumns?: string[];
  allowedFilterFields?: string[];
}

export interface ParsedQuery {
  page: number;
  limit: number;
  offset: number;
  sortField: string;
  sortAsc: boolean;
  search?: string;
  filters: Record<string, any>;
}

export class QueryHelper {
  static parse(req: Request, options: QueryOptions): ParsedQuery {
    const rawPage = parseInt(req.query.page as string, 10);
    const page = !isNaN(rawPage) && rawPage > 0 ? rawPage : 1;

    const maxLimit = options.maxLimit || 100;
    const defaultLimit = options.defaultLimit || 20;
    const rawLimit = parseInt(req.query.limit as string, 10);
    const limit = !isNaN(rawLimit) && rawLimit > 0 ? Math.min(rawLimit, maxLimit) : defaultLimit;

    const offset = (page - 1) * limit;

    // Sorting with strict allowlisting
    let sortField = options.defaultSortField || 'created_at';
    let sortAsc = options.defaultSortAsc !== undefined ? options.defaultSortAsc : false;

    if (req.query.sort && typeof req.query.sort === 'string') {
      const parts = req.query.sort.split(':');
      const requestedField = parts[0]?.trim();
      const requestedOrder = parts[1]?.toLowerCase().trim();

      if (options.allowedSortFields.includes(requestedField)) {
        sortField = requestedField;
        sortAsc = requestedOrder === 'asc';
      }
    }

    // Search query with SQL wildcard escaping
    let search: string | undefined;
    if (req.query.search && typeof req.query.search === 'string') {
      const cleanSearch = req.query.search.trim().replace(/[%_]/g, '\\$&');
      if (cleanSearch.length > 0 && cleanSearch.length <= 256) {
        search = cleanSearch;
      }
    }

    // Extract query filters with strict allowlisting and key format validation
    const controlKeys = new Set(['page', 'limit', 'sort', 'search']);
    const filters: Record<string, any> = {};
    const safeKeyRegex = /^[a-zA-Z0-9_]{1,64}$/;

    for (const [key, value] of Object.entries(req.query)) {
      if (!controlKeys.has(key) && value !== undefined && value !== '') {
        // Enforce allowed filter fields if specified
        if (options.allowedFilterFields) {
          if (options.allowedFilterFields.includes(key) && safeKeyRegex.test(key)) {
            filters[key] = value;
          }
        } else if (safeKeyRegex.test(key)) {
          filters[key] = value;
        }
      }
    }

    return {
      page,
      limit,
      offset,
      sortField,
      sortAsc,
      search,
      filters,
    };
  }

  static formatResult<T>(items: T[], total: number, page: number, limit: number): PaginatedResult<T> {
    return {
      items,
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit) || 1,
    };
  }
}
