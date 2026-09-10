import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './context/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import Layout from './components/Layout';

// Pages
import Login from './pages/Login';
import Unauthorized from './pages/Unauthorized';
import Dashboard from './pages/Dashboard';
import Users from './pages/Users';
import UserDetail from './pages/UserDetail';
import Teachers from './pages/Teachers';
import Students from './pages/Students';
import Universities from './pages/Universities';
import Faculties from './pages/Faculties';
import Departments from './pages/Departments';
import Courses from './pages/Courses';
import Subscriptions from './pages/Subscriptions';
import Payments from './pages/Payments';
import AiManagement from './pages/AiManagement';
import AiCostDashboard from './pages/AiCostDashboard';
import Usage from './pages/Usage';
import Plans from './pages/Plans';
import Analytics from './pages/Analytics';
import Notifications from './pages/Notifications';
import Ads from './pages/Ads';
import AuditLogs from './pages/AuditLogs';
import SystemMonitoring from './pages/SystemMonitoring';

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          {/* Direct Admin Access - Bypass Login Wall */}
          <Route path="/login" element={<Navigate to="/" replace />} />
          <Route path="/unauthorized" element={<Navigate to="/" replace />} />

          {/* Protected Admin Routes */}
          <Route
            path="/"
            element={
              <ProtectedRoute>
                <Layout />
              </ProtectedRoute>
            }
          >
            <Route index element={<Dashboard />} />
            <Route path="users" element={<Users />} />
            <Route path="users/:id" element={<UserDetail />} />
            <Route path="teachers" element={<Teachers />} />
            <Route path="students" element={<Students />} />
            <Route path="universities" element={<Universities />} />
            <Route path="faculties" element={<Faculties />} />
            <Route path="departments" element={<Departments />} />
            <Route path="courses" element={<Courses />} />
            <Route path="subscriptions" element={<Subscriptions />} />
            <Route path="payments" element={<Payments />} />
            <Route path="ai" element={<AiManagement />} />
            <Route path="ai/cost" element={<AiCostDashboard />} />
            <Route path="usage" element={<Usage />} />
            <Route path="plans" element={<Plans />} />
            <Route path="analytics" element={<Analytics />} />
            <Route path="ads" element={<Ads />} />
            <Route path="notifications" element={<Notifications />} />
            <Route path="audit-logs" element={<AuditLogs />} />
            <Route path="system" element={<SystemMonitoring />} />

            {/* Legacy /admin/* prefix compatibility */}
            <Route path="admin" element={<Navigate to="/" replace />} />
            <Route path="admin/dashboard" element={<Navigate to="/" replace />} />
            <Route path="admin/ads" element={<Navigate to="/ads" replace />} />
            <Route path="admin/users" element={<Navigate to="/users" replace />} />
            <Route path="admin/teachers" element={<Navigate to="/teachers" replace />} />
            <Route path="admin/students" element={<Navigate to="/students" replace />} />
            <Route path="admin/universities" element={<Navigate to="/universities" replace />} />
            <Route path="admin/faculties" element={<Navigate to="/faculties" replace />} />
            <Route path="admin/departments" element={<Navigate to="/departments" replace />} />
            <Route path="admin/courses" element={<Navigate to="/courses" replace />} />
            <Route path="admin/subscriptions" element={<Navigate to="/subscriptions" replace />} />
            <Route path="admin/payments" element={<Navigate to="/payments" replace />} />
            <Route path="admin/ai" element={<Navigate to="/ai" replace />} />
            <Route path="admin/usage" element={<Navigate to="/usage" replace />} />
            <Route path="admin/plans" element={<Navigate to="/plans" replace />} />
            <Route path="admin/analytics" element={<Navigate to="/analytics" replace />} />
            <Route path="admin/notifications" element={<Navigate to="/notifications" replace />} />
            <Route path="admin/audit-logs" element={<Navigate to="/audit-logs" replace />} />
            <Route path="admin/system" element={<Navigate to="/system" replace />} />
          </Route>

          {/* Fallback */}
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
