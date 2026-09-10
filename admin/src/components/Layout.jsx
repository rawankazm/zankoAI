import React, { useState } from 'react';
import { Outlet, NavLink, useNavigate, useLocation } from 'react-router-dom';
import {
  LayoutDashboard,
  Users,
  GraduationCap,
  BookOpen,
  Building2,
  Library,
  Layers,
  CreditCard,
  Receipt,
  Bot,
  DollarSign,
  Gauge,
  Sliders,
  TrendingUp,
  Bell,
  ShieldCheck,
  Activity,
  LogOut,
  Menu,
  X,
  UserCheck,
  Megaphone,
} from 'lucide-react';
import { useAuth } from '../context/AuthContext';

const navigationGroups = [
  {
    title: 'سەرەکی',
    items: [
      { to: '/', label: 'داشبۆرد', icon: LayoutDashboard },
      { to: '/analytics', label: 'ئامار و گەشە (MAU)', icon: TrendingUp },
    ],
  },
  {
    title: 'بەکارهێنەران',
    items: [
      { to: '/users', label: 'بەڕێوەبردنی بەکارهێنەران', icon: Users },
      { to: '/teachers', label: 'مامۆستایان', icon: UserCheck },
      { to: '/students', label: 'خوێندکاران', icon: GraduationCap },
    ],
  },
  {
    title: 'پێکهاتەی ئەکادیمی',
    items: [
      { to: '/universities', label: 'زانکۆکان', icon: Building2 },
      { to: '/faculties', label: 'کۆلێژەکان', icon: Library },
      { to: '/departments', label: 'بەشە زانستییەکان', icon: Layers },
      { to: '/courses', label: 'کۆرس و وانەکان', icon: BookOpen },
    ],
  },
  {
    title: 'دارایی و پلانەکان',
    items: [
      { to: '/subscriptions', label: 'بەشداریکردن (VIP)', icon: CreditCard },
      { to: '/payments', label: 'پارەدان و مامەڵەکان', icon: Receipt },
      { to: '/plans', label: 'پلان و سنوورەکان', icon: Sliders },
      { to: '/usage', label: 'بەکارهێنانی کوۆتا', icon: Gauge },
    ],
  },
  {
    title: 'هۆشی دەستکرد (AI)',
    items: [
      { to: '/ai', label: 'چاودێری داواکارییەکان', icon: Bot },
      { to: '/ai/cost', label: 'خەرجی و پاراستنی بودجە', icon: DollarSign },
    ],
  },
  {
    title: 'مارکێتینگ و پەیامەکان',
    items: [
      { to: '/ads', label: 'ڕیکلامەکان (Ads)', icon: Megaphone },
      { to: '/notifications', label: 'ئاگادارکردنەوەی گشتی', icon: Bell },
    ],
  },
  {
    title: 'ئاسایش و سیستەم',
    items: [
      { to: '/audit-logs', label: 'تۆماری ئاسایش (Audit)', icon: ShieldCheck },
      { to: '/system', label: 'تەندروستی سیستەم', icon: Activity },
    ],
  },
];

export default function Layout() {
  const { user, adminProfile, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileOpen, setMobileOpen] = useState(false);

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const initial = adminProfile?.full_name?.[0] || user?.email?.[0]?.toUpperCase() || 'A';

  return (
    <div className="min-h-screen bg-slate-950 flex flex-col md:flex-row text-slate-100">
      {/* ─── Mobile Header ─── */}
      <header className="md:hidden flex items-center justify-between p-4 bg-slate-900 border-b border-slate-800 sticky top-0 z-40">
        <div className="flex items-center gap-3">
          <button
            onClick={() => setMobileOpen(!mobileOpen)}
            className="p-2 rounded-xl bg-slate-800 text-slate-300 hover:text-white"
          >
            {mobileOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
          </button>
          <div className="flex items-center gap-2">
            <img src="/logo.png" alt="ZankoAI" className="w-8 h-8 object-contain" />
            <span className="font-bold text-base tracking-tight text-white">ZankoAI Admin</span>
          </div>
        </div>

        <div className="w-8 h-8 rounded-full bg-brand-600 flex items-center justify-center font-bold text-xs text-white">
          {initial}
        </div>
      </header>

      {/* ─── Mobile Drawer Backdrop ─── */}
      {mobileOpen && (
        <div
          className="fixed inset-0 bg-black/70 backdrop-blur-xs z-40 md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* ─── Responsive Sidebar ─── */}
      <aside
        className={`fixed md:sticky top-0 right-0 z-50 h-screen w-72 bg-slate-900/95 md:bg-slate-900/80 backdrop-blur-xl border-l border-slate-800 flex flex-col transition-transform duration-300 ease-in-out ${
          mobileOpen ? 'translate-x-0' : 'translate-x-full md:translate-x-0'
        }`}
      >
        {/* Brand Header */}
        <div className="p-5 border-b border-slate-800/80 flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-brand-600 to-indigo-500 p-0.5 shadow-lg shadow-brand-500/20 flex items-center justify-center">
              <img src="/logo.png" alt="ZankoAI" className="w-full h-full object-contain p-1" />
            </div>
            <div>
              <h2 className="font-bold text-base text-white leading-tight">ZankoAI</h2>
              <span className="text-[11px] text-brand-400 font-medium tracking-wide">
                پانێڵی سەرەکی ئەدمین
              </span>
            </div>
          </div>

          <button
            onClick={() => setMobileOpen(false)}
            className="md:hidden text-slate-400 hover:text-white p-1"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Navigation Items */}
        <nav className="flex-1 overflow-y-auto p-3 space-y-6">
          {navigationGroups.map((group, gIdx) => (
            <div key={gIdx} className="space-y-1">
              <h5 className="px-3 text-[11px] font-bold uppercase tracking-wider text-slate-500">
                {group.title}
              </h5>
              <div className="space-y-0.5 mt-1">
                {group.items.map((item) => {
                  const Icon = item.icon;
                  const isActive =
                    item.to === '/'
                      ? location.pathname === '/'
                      : location.pathname.startsWith(item.to);

                  return (
                    <NavLink
                      key={item.to}
                      to={item.to}
                      onClick={() => setMobileOpen(false)}
                      className={`flex items-center gap-3 px-3 py-2 rounded-xl text-sm font-medium transition-all ${
                        isActive
                          ? 'bg-brand-600 text-white shadow-md shadow-brand-900/30'
                          : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800/60'
                      }`}
                    >
                      <Icon className={`w-4 h-4 shrink-0 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                      <span className="truncate">{item.label}</span>
                    </NavLink>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>

        {/* User Profile & Logout Footer */}
        <div className="p-4 border-t border-slate-800/80 bg-slate-900/40">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="w-9 h-9 rounded-xl bg-gradient-to-br from-indigo-500 to-brand-600 flex items-center justify-center font-bold text-sm text-white shrink-0 shadow-sm">
                {initial}
              </div>
              <div className="min-w-0">
                <p className="text-xs font-semibold text-slate-200 truncate">
                  {adminProfile?.full_name || 'Admin'}
                </p>
                <p className="text-[11px] text-slate-500 truncate">{user?.email}</p>
              </div>
            </div>

            <button
              onClick={handleLogout}
              className="p-2 rounded-xl text-slate-400 hover:text-rose-400 hover:bg-rose-500/10 transition-colors"
              title="دەرچوون"
            >
              <LogOut className="w-4 h-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* ─── Main Content Body ─── */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Navbar */}
        <header className="hidden md:flex items-center justify-between px-8 py-4 border-b border-slate-800/80 bg-slate-900/50 backdrop-blur-md sticky top-0 z-30">
          <div className="flex items-center gap-2 text-xs text-slate-400">
            <span>پانێڵی ئەدمین</span>
            <span>/</span>
            <span className="text-slate-200 font-medium capitalize">
              {location.pathname === '/' ? 'داشبۆرد' : location.pathname.split('/')[1]}
            </span>
          </div>

          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-950/60 border border-emerald-800/50 text-emerald-400 text-xs">
              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" />
              <span>سیستەم چالاکە (Online)</span>
            </div>

            <div className="px-3 py-1 rounded-lg bg-slate-800 border border-slate-700 text-xs text-slate-300">
              دەسەڵات: <span className="font-semibold text-brand-400">بەڕێوەبەر (Admin)</span>
            </div>
          </div>
        </header>

        {/* Page Views Container */}
        <main className="flex-1 p-4 md:p-8 max-w-7xl w-full mx-auto animate-fade-in">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
