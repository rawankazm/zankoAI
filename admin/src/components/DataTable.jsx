import React from 'react';
import { ChevronRight, ChevronLeft } from 'lucide-react';
import LoadingSpinner from './LoadingSpinner';

export default function DataTable({
  columns = [],
  data = [],
  loading = false,
  emptyMessage = 'هیچ داتایەک نەدۆزرایەوە',
  pagination,
  onPageChange,
  actions,
  filterBar,
}) {
  return (
    <div className="glass-card rounded-2xl border border-slate-800 overflow-hidden flex flex-col">
      {/* Filter and Actions Bar */}
      {(filterBar || actions) && (
        <div className="p-4 border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-3 bg-slate-900/40">
          <div className="flex-1 flex items-center gap-3">{filterBar}</div>
          {actions && <div className="flex items-center gap-2">{actions}</div>}
        </div>
      )}

      {/* Table Content */}
      <div className="overflow-x-auto min-h-[300px] relative">
        {loading && (
          <div className="absolute inset-0 bg-slate-950/60 backdrop-blur-xs flex items-center justify-center z-10">
            <LoadingSpinner size="md" />
          </div>
        )}

        <table className="w-full text-right text-sm">
          <thead className="text-xs uppercase bg-slate-900/80 text-slate-400 border-b border-slate-800">
            <tr>
              {columns.map((col, idx) => (
                <th key={col.key || idx} className={`px-4 py-3.5 font-semibold ${col.className || ''}`}>
                  {col.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-800/60">
            {!loading && data.length === 0 ? (
              <tr>
                <td colSpan={columns.length} className="px-4 py-12 text-center text-slate-500">
                  {emptyMessage}
                </td>
              </tr>
            ) : (
              data.map((row, rIdx) => (
                <tr key={row.id || rIdx} className="hover:bg-slate-800/30 transition-colors">
                  {columns.map((col, cIdx) => (
                    <td key={cIdx} className={`px-4 py-3.5 text-slate-300 ${col.className || ''}`}>
                      {col.render ? col.render(row[col.key], row, rIdx) : row[col.key]}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {/* Pagination Footer */}
      {pagination && (
        <div className="p-4 border-t border-slate-800/80 flex items-center justify-between text-xs text-slate-400 bg-slate-900/40">
          <div>
            پیشاندانی <span className="font-semibold text-slate-200">{data.length}</span> لە کۆی{' '}
            <span className="font-semibold text-slate-200">{pagination.total || 0}</span> تۆمار
          </div>

          <div className="flex items-center gap-2">
            <button
              onClick={() => onPageChange?.(pagination.page - 1)}
              disabled={pagination.page <= 1 || loading}
              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed text-slate-200 transition-colors"
              title="پەڕەی پێشوو"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
            <span className="px-2">
              پەڕەی <span className="font-semibold text-slate-200">{pagination.page}</span> لە{' '}
              <span className="font-semibold text-slate-200">{pagination.totalPages || 1}</span>
            </span>
            <button
              onClick={() => onPageChange?.(pagination.page + 1)}
              disabled={pagination.page >= (pagination.totalPages || 1) || loading}
              className="p-1.5 rounded-lg bg-slate-800 hover:bg-slate-700 disabled:opacity-40 disabled:cursor-not-allowed text-slate-200 transition-colors"
              title="پەڕەی دواتر"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
