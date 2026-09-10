import React, { useState } from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Lock, Mail, ShieldAlert, ArrowLeft, KeyRound } from 'lucide-react';
import { useAuth } from '../context/AuthContext';
import LoadingSpinner from '../components/LoadingSpinner';

export default function Login() {
  const { login, resetPassword, authError } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [errorMsg, setErrorMsg] = useState('');
  const [resetSent, setResetSent] = useState(false);
  const [showForgot, setShowForgot] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!email || !password) {
      setErrorMsg('تکایە ئیمەیڵ و وشەی تێپەڕ بنووسە.');
      return;
    }

    setLoading(true);
    setErrorMsg('');

    const res = await login(email, password);
    setLoading(false);

    if (res.success) {
      const destination = location.state?.from?.pathname || '/';
      navigate(destination, { replace: true });
    } else {
      setErrorMsg(res.error || 'چوونەژوورەوە سەرکەوتوو نەبوو.');
    }
  };

  const handleResetPassword = async (e) => {
    e.preventDefault();
    if (!email) {
      setErrorMsg('تکایە ئیمەیڵ بنووسە بۆ ناردنی بەستەری گۆڕینی وشەی تێپەڕ.');
      return;
    }
    setLoading(true);
    const res = await resetPassword(email);
    setLoading(false);
    if (res.success) {
      setResetSent(true);
    } else {
      setErrorMsg(res.error || 'هەڵە لە ناردنی بەستەری گۆڕین.');
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center p-4 bg-slate-950 relative overflow-hidden">
      {/* Background Ambience Glow */}
      <div className="absolute top-1/4 -right-20 w-96 h-96 bg-brand-600/15 rounded-full blur-3xl pointer-events-none" />
      <div className="absolute bottom-1/4 -left-20 w-96 h-96 bg-indigo-500/15 rounded-full blur-3xl pointer-events-none" />

      <div className="w-full max-w-md glass-card rounded-3xl p-8 border border-slate-800 shadow-2xl relative z-10 animate-fade-in">
        {/* Brand Header */}
        <div className="text-center mb-8">
          <div className="w-16 h-16 rounded-2xl bg-gradient-to-tr from-brand-600 to-indigo-500 p-0.5 shadow-xl shadow-brand-500/25 mx-auto mb-4 flex items-center justify-center">
            <img src="/logo.png" alt="ZankoAI Logo" className="w-full h-full object-contain p-2" />
          </div>
          <h1 className="text-2xl font-bold text-white tracking-tight">ZankoAI Admin</h1>
          <p className="text-xs text-slate-400 mt-1.5">
            پانێڵی تایبەتی بەڕێوەبەرایەتی سیستەمی زانکۆ ئەی ئای
          </p>
        </div>

        {/* Error Alert */}
        {(errorMsg || authError) && (
          <div className="mb-6 p-4 rounded-2xl bg-rose-500/10 border border-rose-500/20 text-rose-300 text-xs flex items-start gap-3">
            <ShieldAlert className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
            <p className="leading-relaxed">{errorMsg || authError}</p>
          </div>
        )}

        {resetSent && (
          <div className="mb-6 p-4 rounded-2xl bg-emerald-500/10 border border-emerald-500/20 text-emerald-300 text-xs leading-relaxed">
            بەستەری گۆڕینی وشەی تێپەڕ بە سەرکەوتوویی نێردرا بۆ ئیمەیڵەکەت.
          </div>
        )}

        {!showForgot ? (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">
                ئیمەیڵی ئەدمین
              </label>
              <div className="relative">
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@zankoai.com"
                  required
                  className="w-full pl-4 pr-10 py-3 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-500 transition-all"
                  dir="ltr"
                />
                <Mail className="w-4 h-4 text-slate-400 absolute right-3.5 top-3.5" />
              </div>
            </div>

            <div>
              <div className="flex items-center justify-between mb-2">
                <label className="text-xs font-semibold text-slate-300">
                  وشەی تێپەڕ (Password)
                </label>
                <button
                  type="button"
                  onClick={() => setShowForgot(true)}
                  className="text-xs text-brand-400 hover:text-brand-300 transition-colors"
                >
                  لەبیرت چۆتەوە؟
                </button>
              </div>
              <div className="relative">
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="••••••••••••"
                  required
                  className="w-full pl-4 pr-10 py-3 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-500 transition-all"
                  dir="ltr"
                />
                <Lock className="w-4 h-4 text-slate-400 absolute right-3.5 top-3.5" />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3.5 px-4 rounded-xl bg-brand-600 hover:bg-brand-500 text-white font-semibold text-sm shadow-lg shadow-brand-900/40 flex items-center justify-center gap-2 transition-all disabled:opacity-50 mt-6"
            >
              {loading && <LoadingSpinner size="sm" />}
              <span>چوونەژوورەوە وەک ئەدمین</span>
            </button>
          </form>
        ) : (
          <form onSubmit={handleResetPassword} className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-slate-300 mb-2">
                ئیمەیڵ بۆ گۆڕینی وشەی تێپەڕ
              </label>
              <div className="relative">
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  placeholder="admin@zankoai.com"
                  required
                  className="w-full pl-4 pr-10 py-3 rounded-xl bg-slate-900/80 border border-slate-700/80 text-sm text-white placeholder-slate-500 focus:outline-none focus:border-brand-500 focus:ring-1 focus:ring-brand-500 transition-all"
                  dir="ltr"
                />
                <Mail className="w-4 h-4 text-slate-400 absolute right-3.5 top-3.5" />
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3.5 px-4 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-sm shadow-lg shadow-indigo-900/40 flex items-center justify-center gap-2 transition-all disabled:opacity-50 mt-4"
            >
              {loading && <LoadingSpinner size="sm" />}
              <KeyRound className="w-4 h-4" />
              <span>ناردنی بەستەری گۆڕین</span>
            </button>

            <button
              type="button"
              onClick={() => {
                setShowForgot(false);
                setResetSent(false);
              }}
              className="w-full py-2 text-xs text-slate-400 hover:text-white flex items-center justify-center gap-1 transition-colors mt-2"
            >
              <ArrowLeft className="w-3.5 h-3.5" />
              <span>گەڕانەوە بۆ چوونەژوورەوە</span>
            </button>
          </form>
        )}

        <div className="mt-8 pt-6 border-t border-slate-800/80 text-center">
          <p className="text-[11px] text-slate-500">
            تەنها ئەدمینی فەرمی زانکۆ ئەی ئای ڕێگەپێدراوە. هەموو هەوڵە نایاساییەکان تۆمار دەکرێن.
          </p>
        </div>
      </div>
    </div>
  );
}
