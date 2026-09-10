import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { ShieldX, LogOut, ArrowRight } from 'lucide-react';
import { useAuth } from '../context/AuthContext';

export default function Unauthorized() {
  const { user, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const customError = location.state?.error;

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-slate-950">
      <div className="w-full max-w-lg glass-card rounded-3xl p-8 border border-rose-900/40 shadow-2xl text-center">
        <div className="w-16 h-16 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-400 mx-auto mb-6 flex items-center justify-center">
          <ShieldX className="w-8 h-8" />
        </div>

        <h1 className="text-2xl font-bold text-white mb-2">دەستگەیشتن ڕەتکرایەوە (403 Forbidden)</h1>
        <p className="text-sm text-slate-400 mb-6 leading-relaxed">
          {customError || 'هەژمارەکەت مۆڵەتی ئەدمینی نییە بۆ بەکارهێنانی ئەم پانێڵە. ئەم پەڕەیە تەنها بۆ بەڕێوەبەرانی فەرمی زانکۆ ئەی ئای تەرخانکراوە.'}
        </p>

        {user && (
          <div className="p-4 rounded-xl bg-slate-900/80 border border-slate-800 text-xs text-slate-300 mb-6 text-right space-y-1.5">
            <div>ئیمەیڵی تۆمارکراو: <span className="font-mono text-slate-100">{user.email}</span></div>
            <div>ناسنامە (UID): <span className="font-mono text-slate-400">{user.id}</span></div>
            <div className="text-rose-400 font-semibold mt-1">پلەی ئەدمین دیارینەکراوە لە داتابەیسدا.</div>
          </div>
        )}

        <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
          <button
            onClick={handleLogout}
            className="w-full sm:w-auto px-6 py-3 rounded-xl bg-rose-600 hover:bg-rose-500 text-white font-medium text-sm shadow-lg shadow-rose-900/30 flex items-center justify-center gap-2 transition-all"
          >
            <LogOut className="w-4 h-4" />
            <span>چوونەدەرەوە و گۆڕینی هەژمار</span>
          </button>
          <button
            onClick={() => navigate('/login')}
            className="w-full sm:w-auto px-6 py-3 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-300 hover:text-white font-medium text-sm transition-all flex items-center justify-center gap-2"
          >
            <ArrowRight className="w-4 h-4" />
            <span>گەڕانەوە بۆ چوونەژوورەوە</span>
          </button>
        </div>
      </div>
    </div>
  );
}
